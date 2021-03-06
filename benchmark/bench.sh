#!/bin/bash
ncores=$(lscpu | grep "^CPU(s):" | sed 's/.* //')
scores="$1"; shift
ccores="$1"; shift
((startc=ncores-ccores))
((nc=200/ccores))

if ((scores+ccores>ncores)); then
	echo "Cannot use more server+client cores than there are CPU cores" >/dev/stderr
	exit 1
fi

((ends=scores-1))
((endc=ncores-1))

command -v numactl >/dev/null 2>&1
no_numa=$?

args=()
for i in "$@"; do
	if [ "$i" == "CCORES" ]; then
		args+=("$ccores")
	elif [ "$i" == "SCORES" ]; then
		args+=("$scores")
	else
		args+=("$i")
	fi
done

if [ $no_numa -eq 1 ]; then
	echo env GOMAXPROCS=$scores "${args[@]}" -p 2222 -U 2222
	env GOMAXPROCS=$scores "${args[@]}" -p 2222 -U 2222 &
	pid=$!
else
	echo numactl -C 0-$ends env GOMAXPROCS=$scores "${args[@]}" -p 2222 -U 2222
	numactl -C 0-$ends env GOMAXPROCS=$scores "${args[@]}" -p 2222 -U 2222 &
	pid=$!
fi

sleep 1

if [ $no_numa -eq 1 ]; then
	echo memtier_benchmark -p 2222 -P memcache_binary -n 20000 -t $ccores -c $nc
	memtier_benchmark -p 2222 -P memcache_binary -n 20000 -t $ccores -c $nc 2>/dev/null
else
	echo numactl -C $startc-$endc memtier_benchmark -p 2222 -P memcache_binary -n 20000 -t $ccores -c $nc
	numactl -C $startc-$endc memtier_benchmark -p 2222 -P memcache_binary -n 20000 -t $ccores -c $nc 2>/dev/null
fi

kill $pid
wait $pid 2>/dev/null
