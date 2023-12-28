source ./scripts/bash/groth16/phase2_circuit_groth16.sh

compile_phase2 ./solidity-fixtures/solidity-fixtures/masp_vanchor/2 masp_vanchor_2_2 ./artifacts/circuits/masp_vanchor
move_verifiers_and_metadata_masp_vanchor ./solidity-fixtures/solidity-fixtures/masp_vanchor/2 2 masp_vanchor 2

compile_phase2 ./solidity-fixtures/solidity-fixtures/masp_vanchor/2 masp_vanchor_16_2 ./artifacts/circuits/masp_vanchor
move_verifiers_and_metadata_masp_vanchor ./solidity-fixtures/solidity-fixtures/masp_vanchor/2 2 masp_vanchor 16