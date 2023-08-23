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
            [3842401314073945594713766393773264486809372396188873146907975835957651188557,
             6282143572786493758385094169685719630006980020444674442619117381796998365988],
            [6110145302178107413276826366501840080773283383585192218800961296158337690109,
             13774838497218090653382023257092900695948574859182490283237029002818456384094]
        );
        vk.IC = new Pairing.G1Point[](24);
        
        vk.IC[0] = Pairing.G1Point( 
            18483607521034253117393349202991723816435719898246744336288542842899515711445,
            17472662708393126914376325823385230687359695246340517908565667708638886328135
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            10623383031524410277402692946923638445902537223153914244766338809123317013887,
            4652315552760939570618371062268078589122021176442583759232583377855559850475
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            13845510448518910750985930509785168312925241485873278614469426687954173228688,
            15698194471530556235845985589821502267429173811510241467551595734904362210845
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            10989034278617681005574760331041898184169743126245544018660626593751622636336,
            5129570867736407613904759722696372018625570875915273960450342335893603684585
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            639692653377318511031511255341740193595735882430096849017795728664745530630,
            17890285971699668253464579251697460912925567671094010327237223451365231185619
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            7831968610008895308229705863163445978373047450393946357778859228817035418838,
            10872036553458713206040475647015322273413229973245006067817148460043853685376
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            1169292887942125701521791714101661537148730378907218237563375811860908726844,
            6062781554693607239538353393518603417393729741490713463779970141795821254588
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            5294652264549759223802241191945046423100763317676683215278579712048964837701,
            11290894220348004252125192689665814426857962484337853032638168716428177498660
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            14980716976431571997778222666136638564710564968130033358913729380707279809024,
            18093499607671219775584837672683477968299994145763252584684628301892089836107
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            14335326847871316288012138417685479881699684150200830760066200089034953218021,
            20792144818522604535519582380197578602206138620522218680462288590179843545269
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            11723545933414792680861720495705548021890946364566949308698678181531742086549,
            21597324031204929840118707076735201816011940262278573995080845145520950774830
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            10517248765023944606915693346396882290653064516158636636621803056033194553603,
            3985257296675800232983796489099547122382722836454061655202136770312768582714
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            21503969372837234880292916480235925509697218123316171302933096123005298560221,
            9721888850855653893539754511877243160930595961763954734959696761413290269186
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            5142666920637384831873527746616391997765401478224884041598943380698254930947,
            765835794094883614128708209565590647437792397947399932440384612246603510318
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            16001471067423853274257388503386997597989230782086448707217005613172742398957,
            12046527999723192925776501412846337807213440425287714216480111784689070797246
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            11735935930223996399424059261392791696104197439301100038639667476695757089605,
            520167744603104625721639796615090784993663517904089522566864285489874636134
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            20861752199979591138421391192041368656823419735436464392072757530247596937532,
            11164554775580327375309336121893433259367765766901111222261732545637274833669
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            6295686248617996679209289792257818387008514639635232025616647070663942417169,
            9088742293578127445054822740010530893122913401005718314509757478856716636207
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            7127552420454627147542829032518692128245245156236931364881728645031675853397,
            21575892078483890535475913495900729881352786124732955781823541386260613244683
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            14732125938431656381159450193919797053100028552775601468171175248436079384133,
            7379155996150229487739660698614681834915715745878131987216605806804009122737
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            3028711287015695575732069915384546462182589301005100753614846882795741508335,
            6856092915957145598107230287512775492648708029100729542684529714431294424441
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            18322541472333016954308189049974793472043226487810471609098999069953870033195,
            18518129031052102217190709450298024790773382948160923391201635124897192805193
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            6998383019154873579036007606948127944952401292348380764705548471379171466813,
            11214777225703822629032845673123330009501727673004326507987370800687567497714
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            4539528458948304627667615415582531032623650047545591763416380659125361961609,
            2684405714624687373158252017476594190445357368744518788997774028959817293959
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
            uint[23] memory input
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
