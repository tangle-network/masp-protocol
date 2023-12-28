source ./scripts/bash/groth16/phase2_circuit_groth16.sh

compile_phase2 ./solidity-fixtures/solidity-fixtures/masp_vanchor/8 masp_vanchor_2_8 ./artifacts/circuits/masp_vanchor
move_verifiers_and_metadata_masp_vanchor ./solidity-fixtures/solidity-fixtures/masp_vanchor/8 8 masp_vanchor 2

compile_phase2 ./solidity-fixtures/solidity-fixtures/masp_vanchor/8 masp_vanchor_16_8 ./artifacts/circuits/masp_vanchor
move_verifiers_and_metadata_masp_vanchor ./solidity-fixtures/solidity-fixtures/masp_vanchor/8 8 masp_vanchor 16