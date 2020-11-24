from sys import stdout

from mininet.node import Controller
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.log import info, setLogLevel
from subprocess import call
import shlex

import os

def tag(host):
    return host.name

def kill(host):
    cmd = ("screen -X -S {0} kill").format(host.name)
    print("calling: " + cmd)
    call(shlex.split(cmd))


def setup(hosts, cgrps, logs, **kwargs):
    cluster = ",".join(str(i+1) + ":"+host.IP()+":2380" for i, host in
            enumerate(hosts)
                )

    restarters = {}
    stoppers = {}

    print(hosts)
    print([host.IP() for host in hosts])

    def run(cmd, tag, host):
        cmd = "screen -dmS {tag} bash -c \"{command} 2>&1 | tee -a {logs}_{tag}\"".format(tag=tag,command=cmd, logs=logs)
        host.popen(shlex.split(cmd), stdout=stdout)
        return cmd

    for i, host in enumerate(hosts):
        start_cmd = (
                "systems/ocaml-paxos/bins/ocamlpaxos " +
                "{node_id} " 
                "{addrs} " + 
                "{data_dir} " + 
                "2379 "+
                "2380 " + 
                "5 " + 
                "0.1 "
                ).format(
                        node_id=str(i+1),
                        addrs=cluster,
                        data_dir="/data/" + tag(host),
                        )


        run(start_cmd, tag(host), host)
        print("Start cmd: " + str(start_cmd))

        restarters[tag(host)] = lambda:run(start_cmd, tag(host), host)
        stoppers[host.name] = shlex.split(("screen -X -S {0} quit").format(host.name))

    return restarters, stoppers
