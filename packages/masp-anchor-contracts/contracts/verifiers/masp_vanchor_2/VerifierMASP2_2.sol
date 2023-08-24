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
contract VerifierMASP2_2 {
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
            [20891154015595529246617055732832926525646113222928145894378073875666383216941,
             10583376133403190023942328110547943007493808013144192775897245364467615306633],
            [6551152184715838603387047290874492861887508531361238292764132486202216579826,
             17061829959671898703211850426888077156556327107890698030570371736951380764466]
        );
        vk.IC = new Pairing.G1Point[](26);
        
        vk.IC[0] = Pairing.G1Point( 
            4977005709752562571292091562555369989834923252487119241065776125905404293865,
            19815689419986089410830059316840038171133358677020889479381800358855580542257
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            1017352949248658806586097681028730117815240375288767187636953563999273511626,
            18081214169686309775113443563281498806868887132614961374982733802426607697220
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            12632456586455840108034426378232171935396900088475030968662154648573325322920,
            19832502349753633896183553695875653777548887783018789894885789604299368868790
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            4982056901258439906104355176108435122005590510003815860941972095449279964386,
            10791783789844077678097339997647231325200488237735722135972994104636521538778
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            21720133033129141588071538559805398281292775306948105453858299058402555482185,
            15065885059282332913053865448424230731310749451556216567838803681563421757669
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            19755334166330317347219348114558108175400412104821584900048769288991568323485,
            9345149815710482849616043059843886183849025132908378062460574848788615483497
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            2244759244786807935086703528034199122341806701222913836290999718279313387502,
            19723729799787084377148843561662058523966456320012867992981360866304329210858
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            21849187167287013394821058780323270160029315724221281694605128470010601156229,
            11193255198026976895975644672178846392597465130084177512002371833547182767895
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            13992878109411878826476022844769521200078970480830170398108716193099210465717,
            2917834668576581461446108279897660342515992454562945142037459197050759510000
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            13512868166912643799955711496129487770166955579717776642591224745978400580929,
            13009549725438061218829946891428448779941502994953190253654916261592148783563
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            3947135016170402289262078076507837987347350737203041536878125327192211931163,
            15790679365669826842934729612069350484999702784740077035877785882636206038761
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            18568814526494893073740933087612029477954831707522518206646808775825324220930,
            10516014914280541291351139053205403190838552959636942797337605969196974074839
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            4632312302613379146190691444866167378141494307458139348410861059170766312149,
            14484341178907260721125894740540618999230588042941373227522290631476877010865
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            18153302629603408036701733939457760624741904379252715342116193095500271330170,
            19203777361186760455049857561586359098919247169303230598239008537721309241438
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            11319981611709663520804531587171803192003079007508997934766131796703608639917,
            10231602158621306062041646006149068013589676969165824129555482313487373761591
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            1454647135878384884297112829055096707946685990057594871440254230360927189515,
            6060434469695606119315676372807836831463779604717922005131102532805668825911
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            6985962031618592620410829706820557102364030021121420944598902601353293049506,
            7822662902737736664073406193621375460102015923117181572947985813930659033108
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            9672879501567492502782206599212298850031627231830699451448835390762847473904,
            16031130068576517618452996233264761374049272703862640186713886572784796419616
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            12416305894864267337140128075075764651119900459301111797274720155176675895256,
            19587821982715990938346221545127901751393896990870074474436803454548716540830
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            8668396170416830076712388601124824606145809018680948637964935940102278635613,
            10553563577508275899322865040929387344113424503676630342243883207285550512124
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            20830387062294555265435679355962518349987770708692010319896330604588000881499,
            15220019770952812549982410368653973305106665099040628565257606982638264511358
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            16811802199962515703248909396673710746376807229642064555378976590850170617853,
            18098601107139492004875990785650525029659517183191597515515803267921200503600
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            3166582879506658552526570628635233417411665797803933408016736169980076055568,
            17528950841433892344118684168205666001622544696879655085554047252818192394085
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            12809896394255776927753970086389319465876972521385500612643633698481364284812,
            10471496714831941792570715407281851260513572166524806831110234686749149101926
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            14442428655752233981207718112566488570440296725074938680768696547155775677544,
            13336867679753641126132279646140190028720618960245788781936635399673659267324
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            12889046240623871624124038200538935877393890446135824550810992972253137749065,
            2441139233271652547444677503946095769805403403490926097629196022353971317442
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
            uint[25] memory input
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
