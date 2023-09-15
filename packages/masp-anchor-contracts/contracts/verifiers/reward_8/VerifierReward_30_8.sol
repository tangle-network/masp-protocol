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
            [16867768191552789333182913112653640002575805520852235648707062639355968187386,
             7385636310865115599683789819328145133178972582111122624872354186658897098899],
            [16445455836291953909748111524997427618468830120925197419515861113818205776813,
             17054376036178577152859411506913591153207295832624158062573264134377099984416]
        );
        vk.IC = new Pairing.G1Point[](31);
        
        vk.IC[0] = Pairing.G1Point( 
            2906998252702783034419369690534490802848552733397540421908570388462424906612,
            16721522596389503178665487706457467256940603473323795307097223911903888605524
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            1601260111837889058647929387803973818241116127218056909221539636537512511710,
            4297913580087772871333970969817112077648525228720366797591855563728461432873
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            6023461179783214676342507122642991979261196713018764093929909728264202353106,
            17110507146536544182450763248581643996643545365504595600880952799776229538268
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            4125075792807289427965639222172228857192948998048607955060789282514689698849,
            249904363272944888728231980657876569640627287911703225789520960386748596405
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            15642507459726380478142196466380387775236746880456691481694070860642032078156,
            761460985158253837312414233712753998966099334762221590127639654720328376071
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            9326854054067047336636207345508231173790948380724702087023432425240700557739,
            16315081628672261152215909623876063617343051142038627540476205671717441423051
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            18326903919621857932678391035321007218134514827273747117010736098376580336947,
            13457620726106547511015703924741238604428735594051592480715877086561927996858
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            4038472552774727367232808686955642857300714036199495707506901581944217564971,
            396690677180743707540156008958177333059741128426262910885946815625307323731
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            1951060990264792482949838458492856225051546480463477965785467398102156388192,
            4725664642011045823610397099768391885402986968681942332618087641395660618277
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            2988357038069918550226037493011507775091923613662342584484363339367883682629,
            8304979328476326717099184523297720107359265711562267328327764398784339583137
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            18031502361973612137204719879836423668265783203928294735994349226165028529646,
            14375904992869228234490191965804437407871882456164052117964269651064932608710
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            21460427117428343074211476057250267512008783785793113449277632596385887137428,
            21739078896980802351545704784802671032711259298068243429530701758373855587814
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            9657561965383130167299869111428366142588359476279028438027727104932657768902,
            5308749989077786352698600348873987857325591682488875875138244427828646046424
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            332587633014880571761866190736436958367912419874396914168685679112651243588,
            12993206655061833118360105566190624565691746093049092370939830818849046626529
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            575985153305998222798490273571078843597932644049634897074806212483694350257,
            1985049532140137702602158007577462197537620459878142741883975356111084666383
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            18054151444026564822092062549042990830334241834692718468079777857947182030428,
            4845886771607072494920636038633656333987908400547416251524133895409080712982
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            931189743497261008988871482483180305371758912925741828266273310449017176654,
            2918831617109531957139095142696623756817700425301550338042108445583092775791
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            1113068501692630686524702321080621332445633724705643523576264817489716938125,
            21856247986172669920217987865145625112863064332091300983626018545238666717302
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            16827842561996530374704568659427376745003141505756343099890064266382915986799,
            17698603458899692161861053716720301799951570171360241791233092921453383856444
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            12718836350464736599859243437860800899644036660665050837523431388399957646631,
            8044602523179112949374116299253976978263923194704043028297451715310969281038
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            19507416697989596599998206123527973759938768335484173962223411230998921434679,
            20734424517173666237295695065722742807943478142354373087246272273225099223387
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            19422801596045005836443313918037104591087451256473224672636756490672923402481,
            3505073794994326193172800955729018090394309201983537606589955064278544639831
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            14795420653358738931029458379275995861869975496664990679535850588632179295880,
            3336209788363911004910296711167806419684934595583618737462692623094764627083
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            6139008391511939620374987506923338108993113200070790653290356821910765927668,
            4364243692967685725595969011919515477610305749822917217295640969316842288094
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            17258961922584516291439744693549250365960049025317338637670752426385076666334,
            10005323944295577344990227952829344515044081337012031793601284936681625394748
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            15926613817518523286058534838183589827336052167120246567157898708460325599006,
            12858846530922637926243378362034800969608234588118504115979628429757399537042
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            14859557158699041031588610625950311806543633746400106845731310789720391894631,
            18850017003756144614002469763309297423505740976446973583451194052677419056168
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            917677702540098188737043676828277316271851319799601860950329087523809965711,
            21107660452656304258850329739432593030771704334233666681760927143327069005620
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            12514862508184210138713611132004279702739231624689281176710791716541449233032,
            12639168348695911879313271265934820311787971988712997938215391328587194400217
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            14612837663012675642114221067004137700708047508909335462161525844533236664252,
            7921766987803848638966444462891219853442217150086013108527283127701439181744
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            8683998426193745524610867262273815650525242920240862715698368308366048761613,
            1896553900919756013838843622933356900011969580450676112026943636469246422851
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
            uint[30] memory input
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
