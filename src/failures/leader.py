from mininet.node import Controller
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.log import info, setLogLevel
from subprocess import call
import importlib

setLogLevel('info')

def leader_down(net, restarters, stoppers, service_name, state):
    hosts = [ net[hostname] for hostname in filter(lambda i: i[0] == 'h', net.keys())]
    ips = [host.IP() for host in hosts]
    print(ips)

    print("FAILURE: Stopping Leader")
    leader = importlib.import_module('systems.%s.scripts.find_leader' % service_name).find_leader(hosts, ips)

    print("Sending stop to", leader.name)
    call(stoppers[leader.name])
    state['res'] = restarters[leader.name]

def leader_up(state):
    print("FAILURE: Bringing leader back up")
    state['res']()

def setup(net, restarters, stoppers, service_name):
    state  = {}
    return [
            lambda: leader_down(net, restarters, stoppers, service_name, state),
            lambda: leader_up(state)
            ]
