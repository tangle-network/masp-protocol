#!/bin/bash

# Run each of these processes in parallel
./scripts/bash/groth16/batch_tree/phase2_batch_tree.sh &
./scripts/bash/groth16/masp_vanchor/phase2_masp_vanchor2.sh &
./scripts/bash/groth16/masp_vanchor/phase2_masp_vanchor8.sh &
./scripts/bash/groth16/masp_vanchor/phase2_reward.sh &
./scripts/bash/groth16/masp_vanchor/phase2_swap.sh &

# Wait for all background processes to finish
wait
