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
contract VerifierReward_30_8 {
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
            [13908110507512166360789299536824398594564053218129550720138459525066768225487,
             8068550968352935861112892113270327377207563179259836203801773839167836637393],
            [18486127296547279357446479344987046741936978855978966148991409553174641095822,
             1616168945704635739160181091443372760699823783772481968939266094095325659819]
        );
        vk.IC = new Pairing.G1Point[](21);
        
        vk.IC[0] = Pairing.G1Point( 
            8151753162535664785548291755484393650492912783892721098448760025672961634957,
            18509151406239779247228905696482330792626380557783515149276234129422816364596
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            9255296247941812869442487848894797187263262688871837926031277375715622801647,
            20202320274754262479577294650422170907244876334758018619456402092706975234393
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            2770502522419023611890811217185979969334696750572274367469828143390835942003,
            16477764678947673640987137620038977019935104785333047714180907635867886689579
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            14669691385641075713547222461863666426110315476560449155229255167397905281343,
            15401631189182794752007667348178596960246864362784350688678631339724934484650
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            3501143699468874808860051130624534681517472570476000013049840685189891759614,
            4959555390573533273242483833761490270009377784309090542894250929155916471214
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            15962747424287308372941901294299317927051178532455619057829018153313558292029,
            4059210729881680445497067955944298036328306799488279524056576993951298966704
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            16034385643570473788327521224304945319159706526692069506113233319312663504997,
            376147355945359484266001324528862129504003350598018354702118720352061038804
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            20188550202518960734450765665061276642653179360982362114432850761184228275649,
            4858486153985970899089938034780457591578962453120479601725269793972353239633
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            12386267241611621189443127046349545871662311682233921709986759011872142770679,
            17045605007767919069721621919531979774754397434846739649720582962004138345602
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            8035106166518020011912058102142748512856487205204245128114607210973207310229,
            21279052213638974818062878392093082792984034927448343804914865446962275396607
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            7422635502384994100683023744519302108891682005329849831082177632122237418799,
            19588879777935972502983464345283535520127519902471650240246304994380147369918
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            18053809637881768926170910150435679458284827700619975163362082327774080901725,
            11528599034714595408515861113203909641251846306170816474049854408436280627024
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            4463520019559139600407866999041123696044552258025376391534845942318340168744,
            2918062536331643912319773771526008040280837996049726846453926090123265262981
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            17523795718916167452901155620013398597621545519349391730951925928423150087346,
            10423377031710199760971063594757345614192284628154413048282681145028567705412
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            4686090964708944734211574929498851608005642356318039877714592022888503038520,
            13249431220068476782476530300657980951865721712861321470850303060103322629433
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            9526157002326156119533990209419074869125511753267057631311459900903955885207,
            2208482466920431279349864286189749772620758671417757458346656055811490617249
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            1731025587140170520264474025921782719153414368314205178277677369880878267368,
            7820182736352116947990957289413017880467029605829929348776672050569660744878
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            9627247918834455977656347015199629822594386809066379321993853771549447846207,
            8083985580754398344010744844430811983812466771550973286972967778572163097287
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            15140109296115245590051653996589646312871289343347800817263130702452366245824,
            14335572812087258380760032864420505680027740783074096468926125580137415167363
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            8835892699021943774814738498878427752073155543534209329515555571284110603452,
            10990470175971501607799727469324998267509587906134927593566526930656896288091
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            11556591521083501779822945589752946998245769527493762222964425067956665712100,
            4267566519168736580050471682879237066053548048478664087757511848211308543814
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
            uint[20] memory input
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
