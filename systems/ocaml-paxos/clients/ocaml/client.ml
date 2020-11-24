open! Core
open! Async
module OPC = Ocamlpaxos.Client

module Client : Rcclient.S with type t = OPC.t = struct
  module M = Rcclient.Messages

  type t = OPC.t

  let put client k v cid start_time =
    let open M in
    let st = Unix.gettimeofday () in
    let%bind err =
      let open Ocamlpaxos.Types in
      match%bind OPC.op_write client ~k ~v with
      | Success -> return ""
      | ReadSuccess _ -> return ""
      | Failure -> return "Operation failed"
    in
    let end_ = Unix.gettimeofday () in
    return
      {
        response_time = end_ -. st;
        client_start = st;
        queue_start = start_time;
        end_;
        clientid = cid;
        optype = "";
        target = "";
        err;
      }

  let get client key cid start_time =
    let open M in
    let st = Unix.gettimeofday () in
    let%bind err =
      let open Ocamlpaxos.Types in
      match%bind OPC.op_read client key with
      | Success -> return ""
      | ReadSuccess _ -> return ""
      | Failure -> return "Operation failed"
    in
    let end_ = Unix.gettimeofday () in
    return
      {
        response_time = end_ -. st;
        client_start = st;
        queue_start = start_time;
        end_;
        clientid = cid;
        optype = "";
        target = "";
        err;
      }
end

module Test = Rcclient.Make (Client)

let main addrs id result_pipe =
  let client = OPC.new_client addrs in
  Test.run client id result_pipe

let node_list = Command.Arg_type.create @@ String.split ~on:','

let int32 = Command.Arg_type.create Int32.of_string

let command =
  Command.async ~summary:"Client Spawner for OcamlPaxos"
    Command.Let_syntax.(
      let%map_open addrs = anon ("addresses" %: node_list)
      and clientid = anon ("client_id" %: int32)
      and result_pipe = anon ("result_pipe" %: string) in
      fun () ->
        let open Ocamlpaxos in
        let global_level = Async.Log.Global.level () in
        let global_output = Async.Log.Global.get_output () in
        List.iter [ Client.logger; Rcclient.logger ] ~f:(fun log ->
            Async.Log.set_level log global_level;
            Async.Log.set_output log global_output);
        main addrs clientid result_pipe)

let () =
  Fmt_tty.setup_std_outputs ();
  Core.Command.run command
