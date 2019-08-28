from subprocess import call
import numpy as np
from itertools import product

abs_path = '/root/mounted/Resolving-Consensus'


"""
for n, r, nc in product([5], [1], [5]):
    call(
            [
                'python',
                'benchmark.py',
                'zookeeper_java',
                'simple',
                '--topo_args', 'n={0},nc={1}'.format(n, nc),
                'uniform',
                'none',
                '--benchmark_config', 
                    'rate={r},'.format(r=r) +
                    'duration=3600,'+
                    'dest=../results/zk_lf_{n}s_{nc}cli_r{r}.res'.format(n=n, r=r, nc=nc),
                abs_path
            ]
        )

for n in xrange(24, 27, 1):
    for rate in (np.log2(np.linspace(2, 256, num=13))**(1.7))[9:]:
        for system in ['zookeeper_java', 'etcd_go']:
            call(
                    [
                        'python',
                        'benchmark.py',
                        system,
                        'tree',
                        '--topo_args', 'n={0},nc=15'.format(n),
                        'uniform',
                        'none',
                        '--benchmark_config', 
                        'rate={r},'.format(r=rate)+
                        'duration=60,'+
                        'dest=../results/tree_{n}_{r}_{s}.res'.format(n=n,r=rate, s=system),
                        abs_path
                    ]
                )
"""

for rate in sorted(set([int(i) for i in np.logspace(5,5.5,15,base=2)])):
    for n in [2**i+1 for i in range(5,8)]:
        for system in ['zookeeper_java','etcd_go']:
            call(
                    [
                        'python',
                        'benchmark.py',
                        system,
                        'tree',
                        '--topo_args', 'n={0},nc={1}'.format(n, 40),
                        'uniform',
                        'none',
                        '--benchmark_config', 'rate={0},'.format(rate) + 
                            'duration=60,'+
                            'dest=../results/{0}_{1}_{2}.res'.format(n, rate, system),
                            '-d',
                        abs_path,
                    ]
                )
            call(['bash', 'clean.sh'])
"""
for n in [5]:
    for rate in [2,3,4]:
        call(
                [
                    'python',
                    'benchmark_local.py',
                    'zookeeper_java',
                    'simple',
                    '--topo_args', 'n={0},nc={1}'.format(n, 20),
                    'uniform',
                    'none',
                    '--benchmark_config', 'rate={0},'.format(rate) + 
                        'duration=120,'+
                        'dest=../results/{0}_{1}_etcd_verification.res'.format(n, rate),
                        '-d',
                    abs_path
                ]
            )
"""