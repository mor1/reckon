open! Core
open! Async
open! Ppx_log_async


module Messages = Message_types

module type S = sig
  type t

  val put : t -> bytes -> bytes -> int32 -> float -> Message_types.response Deferred.t
  val get : t -> bytes -> int32 -> float -> Message_types.response Deferred.t
end 

let logger =
  let open Async_unix.Log in
  create ~level:`Info ~output:[] ~on_error:`Raise
    ~transform:(fun m -> Message.add_tags m [("src", "Rcclient")])
    ()

module Make (Cli : S) : sig
  type client = Cli.t
  val run : client -> int32 -> string -> unit Deferred.t 
end = struct
  module EB = EndianBytes.LittleEndian
  module MT = Message_types
  module MP = Message_pb
  module PD = Pbrt.Decoder
  module PE = Pbrt.Encoder

  type client = Cli.t

  let perform op client cid start_time i = 
    [%log.debug logger "Submitting request" (i: int)];
    let%bind res = 
      let keybuf = Bytes.create 8 in
      match op with
      | MT.Put {key; value} -> (
          Stdlib.Bytes.set_int64_ne keybuf 0 key;
          Cli.put client keybuf value cid start_time
        )
      | MT.Get {key} -> (
          Stdlib.Bytes.set_int64_ne keybuf 0 key;
          Cli.get client keybuf cid start_time
        )
    in 
    [%log.debug logger "Performed" ~op:(i : int)];
    return res

  let recv_from_br (br : Reader.t) = 
    let open Deferred.Result in
    let open Deferred.Result.Let_syntax in
    let rd_buf = Bytes.create 4 in
    let%bind () = 
      match%bind.Deferred Reader.really_read br rd_buf ~pos:0 ~len:4 with
      | `Eof _ as v-> fail v 
      | `Ok ->  return ()
    in 
    let len = EB.get_int32 rd_buf 0 |> Int32.to_int_exn in
    let payload_buf = Bytes.create len in
    let%bind () = 
      match%bind.Deferred Reader.really_read br payload_buf ~pos:0 ~len 
      with
      | `Eof _ as v -> fail v
      | `Ok -> return ()
    in
    [%log.debug logger "Received op" (len : int)];
    MP.decode_request (PD.of_bytes payload_buf) |> return

  let send payload outfile =
    let p_len = Bytes.length payload in
    let payload_buf = Bytes.create (p_len + 4) in
    Bytes.blit ~src:payload ~src_pos:0 ~dst:payload_buf ~dst_pos:4 ~len:p_len;
    let p_len = Int32.of_int_exn p_len in
    EB.set_int32 payload_buf 0 p_len;
    Writer.write_bytes outfile payload_buf ~pos:0 ~len:(Bytes.length payload_buf)

  let result_loop res_list outfile =
    let iter v =
      let encoder = PE.create () in
      let payload = MP.encode_response v encoder; PE.to_bytes encoder in
      send payload outfile |> return
    in 
    [%log.info logger "Starting to return results"];
    let%bind () = Deferred.List.iter ~how:`Sequential ~f:iter res_list in
    [%log.info logger "Finished returning results"];
    Deferred.unit

  let run client id result_pipe = 
    let%bind result_pipe = Writer.open_file ~perm:0x0755 result_pipe in
    let in_pipe = Reader.create (Fd.stdin ()) in
    [%log.info logger "PRELOAD - Start"];
    let pipe = 
      Pipe.unfold ~init:() ~f:(fun () ->
          match%map recv_from_br in_pipe with
          | Error _ -> None
          | Ok v -> match v with
            | Finalise {msg} -> (
              [%log.debug logger "Got finaliase" (msg: string)];
              None
            )
            | Start {msg=_msg}-> failwith "Got start during preload phase"
            | Op op -> Some (op, ()) )
    in 
    let%bind op_list =
      Pipe.fold pipe ~init:[] ~f:(fun ops v ->
          match v with
          | (MT.{prereq=true; _}) ->
            let%bind _res = perform v.op_type client id (Unix.gettimeofday ()) (-1) in 
            return ops
          | _ -> 
            v :: ops |> return
        )
    in 
    let op_list = List.sort op_list ~compare:(fun a b -> Float.compare a.start b.start) in
    [%log.debug logger "READYING - Start"];
    send (Bytes.create 0) result_pipe;
    let%bind _got_start = 
      match%bind recv_from_br in_pipe with
      | Ok (Start {msg}) ->
        [%log.debug logger "Starting test" (msg : string)];
        Deferred.unit
      | _ -> failwith "Got something other than a ready!"
    in 
    [%log.info logger "EXECUTE - Start"];
    let foldi test_start i acc MT.{prereq=_; start=offset; op_type=op} =
      let start = 
        let open Time in
        let offset = Span.of_sec offset in
        add test_start offset
      in
      let%bind () = at start in
      let res = perform op client id (Unix.gettimeofday ()) i in
      return (res :: acc)
    in 
    let%bind res = Deferred.List.foldi op_list ~init:[] ~f:(foldi @@ Time.now ()) in
    let%bind res_list = res |> List.rev |> Deferred.List.all in
    [%log.info logger "Finished applying ops"];
    result_loop res_list result_pipe
end 
