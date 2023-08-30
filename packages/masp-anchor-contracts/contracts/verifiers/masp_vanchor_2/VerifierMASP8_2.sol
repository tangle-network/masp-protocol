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
contract VerifierMASP8_2 {
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
            [10662231665967339010783908987906972337896168597572637617644855182078608407847,
             15418841915193748740343114549687407459801464517852981576858207746774456263599],
            [1912074647452051869089896644035030596482389276224578035520523556848198292904,
             127786745933579878736987105475253080570513086690544509485808093134632880514]
        );
        vk.IC = new Pairing.G1Point[](32);
        
        vk.IC[0] = Pairing.G1Point( 
            16933057464466014770156411185255572437863873989080461757729278998270416585146,
            2385817809611776789905659659392208262932654386522307051661655149497970774530
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            12341274101139566235802266348087582281077660861374819129269879983618817342091,
            15950466311347211808583043348729890162989571312310064342831565294160502034299
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            12515050894973135594960835378833806752825572374853126185955834754002672903188,
            9742496065511775298336881585085722401621152919727007122418297735867436673967
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            5074007646211423795085385620467708930893559172768686803361635337030955155148,
            332714427691564497561192263487344254572866739884905256631581639804098271930
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            13137406799919292703833114183612291141309086519906284104494086806316721595455,
            3867859029304591572879242777334408023969442080467916214228636459523233632288
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            17384014905770754057577809728022150029836264414344555478792300444676988775745,
            18046318022484901258049706891179391519764132305911370520546319291440296438591
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            21736452389734980234971331183576977541213214719401838399300256686605373044437,
            10895826588115207866994493248577597055820694410660886569362268583819393199338
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            17060710923079919891818825017435859109397293115743303015740579427524308171243,
            4252553167345121713238376983555201597920477741303871829304393666350748427765
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            6531035858816814830296856947013928826671968038488876651970859931324144461796,
            16557885945574144141891170536098615379453734545005007745539976803492237352101
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            2964833964827097488646050130106056730765025467018060204330461264795439531171,
            587362314946147292560364980892902300772219078423473370344391169980180131740
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            5197095661088238381127267615249353676915283905867973789917309903340294725502,
            3277111735117756390732848955847173058948849727192955304230221212498974303850
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            9346788099220593079942864970463952653059953975265065353194720432016301920058,
            19027909283273458394587398634432943085657782355482875263063302261610892386103
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            13988728164280523600228545356899714227501660986856099131044969587134665522703,
            8775689728995164465059991732174733316661034784500602185399344639515861592440
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            7901893038608715447455921400054007699058292928533632563264543453001250127285,
            1723560046615374132874325979369080370884282929198819112075189980928661266179
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            9169106038287875264160579789451840407779522960092353786624851845652850573515,
            5381347253340138304733430314681765082078132579703918193932739125931504832414
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            18418704787867929065910944367450944623245731701579586383097242914949117817872,
            5630611616298525028467838759533184230610725554275989641528799985558434438503
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            7782375313962786376064226194891022950558374444654129073099242043434337606108,
            18887178421978376636947768948628478564639696132254797894801778551208600948372
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            183649911952765827806929288851924552407506113465666489948186066604685247311,
            1098517069881033815008366304423877971468114377836247957809458346549882093993
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            3822643668986516383754748384352517653471372801636575698224933624377168466351,
            19999701931367125428402457741602395489790035003472919002486575553227182859057
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            5798111072783049538582798070091092589416201150170240544261557336031991340981,
            4053520035512028992327305243485422383219067640945727969504252285017596911252
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            8150130156236611060744797402981232211869223461310969013886641212732250457017,
            469790069838587464497246775800364745040819471984977203993188042507499848145
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            14649566073117260416395677236461355226633149546697800147712075448157330015765,
            3740685197594559180319975634150958927663793195197608075203127833165230809979
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            15730868429910954072278354103906386107491858909469991506207649921845592225574,
            17830876497287031547618681814385845519546402589334074091138159116993235079588
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            20909765685726573679210469399563094643657544461193027365123163257000724488924,
            269734317542178218509425486458048083351888122994795235865996161063329609153
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            610490743752821659174234476038424494841307459520929302003678507676071354645,
            19057219826384095560621026867464771785922683172794728235552862412641677647852
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            12926670498829118696408931494898029420281104897149380973051778577777679678267,
            6480034197064767363458391542733945418664279482413247687929289806462448665865
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            18113097887790308681244787704711080933316203759194413424958684132450512180577,
            5753482781531077158436659395131622861987865715728764245121342887897094182732
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            18132257896467117284863671293323015653241556607516871569414742286617940836430,
            8489944070810562737861205566943650978490357372822300793148702233126376436181
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            1900029335722651889537986347985712493289814212162821356534422598855117459412,
            8532063969595527228322390821151381254136736917778561843032475706604335808769
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            334002703703055414223717045282853288932485333846560850423402576624567238353,
            10386083119013500144643855891815471322997825097473926463274130293830858272639
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            21560454167393759713647390653717472743513424292260055599925415337371993920042,
            18379173935994172875844266329735704900649160867669463879726202749965441161927
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            7514164573424362361533167609382699553805035450215468982385656631993406249059,
            95552679518675261227891250209719078746878379259688080976853632418263448562
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
            uint[31] memory input
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
