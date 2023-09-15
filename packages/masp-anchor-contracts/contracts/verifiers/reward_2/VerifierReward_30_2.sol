//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract VerifierReward_30_2 {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [19519731881998478134693198552498073798571876055806697644862352258085700269924,
             8262724251502793521344539336017425133050381280860068753028933706666209815565],
            [8638930437922367884723600093017335963580687203527525669482532428308024346914,
             17155193566178772774039913763051734015974548127213156064095145186707046824486]
        );
        vk.IC = new Pairing.G1Point[](19);
        
        vk.IC[0] = Pairing.G1Point( 
            7815804991358510038753798461580811902002115330157491849487574029424736980094,
            3952023024789405183695763811733161955522063754367948971351293513783172807043
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            3829668743624800327657342213328981653629528604970107540559989372892107263141,
            7572719190785539161225922396230549105364486452623128080084463435411179782890
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            4644113424023415520314074033622739336402960452009553708709766628367136755348,
            3700967058821863078902772752467027515127209925520340088816874700418159464316
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            14999124768236666992791135035364213425280445070554699900580550954224763877737,
            61549801436875827706470000049781815595597237937056652080945685828352107334
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            3985675662711516590912731121244664081972760528639304615428297986189132429031,
            10237129410966283297106304020729570205216364118589674344307389210003854806220
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            1311615256527331886668386406180669044871207702235088309945103503701774390113,
            20620643710929555051885186526538648616546766850853304103767500032795518144687
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            17260745922542416519888763475429288848217963004957085010035168130341635093400,
            18066669339851263893435272320059657908537830248024361717950181016734495066667
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            15920197343574365881861876481164431659926730756041638155115851522023174654691,
            6869418970724204048809003148859787685408718862574920939882784357475621068984
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            3358035773971946245581779023856237278986883928446693850180993438140294549621,
            4579577625927217521042857552807852808971582307845470482237579749084529080314
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            6524954513529001740950763003510961443069559909309340360679014767504793104851,
            222733329000390291012722673811438283718753990550666617093741257695919317622
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            9811399372469604378431481370400052615247793444350076518451008687320938508314,
            3008387086434828604795888611516364268166651627231555162803779416683727240306
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            12546539608559176892590941124343646749015090094305480434306320533958656336538,
            2217988207074307279637636043186908255548135028017625462391428226333366289360
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            21448091798169532927388929014558931853867598696355960570826367561910092563741,
            423683608643330053276875053871271376696509258048895388436663343104514567643
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            1445482222586135663114348016710774057483443254096266577162050144114702852678,
            6374021726382333009814914025691970528604959058904227751813600123931538179281
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            8435882271455428393454155978247943093368360194448628431054106201769671796950,
            3968353688084089438020382831234471431505407447400772466827858267254291602127
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            16251735504661588532132319602317138511188653949266536036356644484973896278415,
            15071281259962035691472365050177220484637931195152447891671847246209258529972
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            4031852003733168641347892990670152397527963983258409226653966076769985404536,
            12946921685448907853203359692561220393625434726646101317138212036808704864749
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            17033316209496424983911185367517901048854218310568103193678888622823215250121,
            21277485251482689718246409603135349309494630396454007821623634567466604260192
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            15057177113252085050007709886888031264340379597570192961291605506281192431921,
            2738430080787995498419858526803109832662305319082326373991077215786817554601
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[18] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
