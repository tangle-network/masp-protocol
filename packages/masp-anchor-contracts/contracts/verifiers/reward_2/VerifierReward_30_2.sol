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
            [18878706007264917721313524653872655477202437894690271569868272767489256393048,
             2152546692155335235204069750588050970164115847974971984536006453016836670412],
            [20549542670494136885308294674357973110858155876881356053832344441161570380139,
             17058320665596193120272086748875601335360644887109621887133352559675344994925]
        );
        vk.IC = new Pairing.G1Point[](28);
        
        vk.IC[0] = Pairing.G1Point( 
            14539898171214240101210528300070702357473826018829422806117425846349758169697,
            20216953346149965262400491172840870220476428812460411687850269511815828317264
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            18974776685181783254783315885459867570073966021597969820532534240941449751437,
            14069102565639395590781319364251768836668105886674872765735296221006020144609
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            15055855315334311231216018778566558219959366522847001360394290403664027207094,
            11193981195631655587940939882217329805875162082220826174574709840543228301243
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            15077626385687909553816061599799378734255652249147782537667570429647074487943,
            16824675069545296648790115134589279914113187402456535195642152588484311930907
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            21102535969142467721160239536350232381029857409450758156989481099654284781241,
            14070891221541012944233975158077385179721221346111079521903836789525430451099
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            16055402853093010427452146722520396392062886984252545782677119645502574630672,
            4097703961808217556480105022634924261442101420122149646385590711814199796662
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            21284993950583112039332006965848289713668350802500716246617613414079090515156,
            15015049088116012308967090498382747063877391112489754935923076556844930803829
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            1246982833924871138946779297225607906029653950667414695656796131723457657886,
            17893189273526028278554214551100164014993986481444009233183745835726616883853
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            1897139043860373422370618451083094176488885440027653370647349412925435854480,
            6292720513399947847439981868622440950456738756731719333217028847478458249765
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            8066550994542308055148590301611335516113114173738139164566714730488731134824,
            11728272221335498749745606017171032514803364201061774780642016139850013244019
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            9612523603672858655723703044565455607084383498866024958958809532490763282740,
            5738204016110582567739201761064206454349038683843067631296676307258559536488
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            8002991907981073544394684919024928035698473196647620153497592393108338773302,
            5729196626990617180451238456713878701878657967661546153992679058210574729176
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            2382815860857699096024365393989164706104118567638769406490372040618851591296,
            17388888177509903629464243766136344215272149336276588100077456421986995853050
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            2710348776314729919257287238469271753771538200956993286768076536058765611288,
            8953414695866252027878844161691162169236118507566149010740335220764559637152
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            14981442453589464635323257098480992698914868300924807105882984474121313455247,
            12682391043083831269332409596634046291744299096392285021576996579353853144418
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            16598958500624384500470112234430917105680392798686364373561101432336383246947,
            15589933470276690134815851845744567705540857708839337491395348137482311070386
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            65022869628263453210050673585532395322118691157149849934379886637703234623,
            4399896368483368597215797867511266665740913135255471242618775307456929590824
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            6169834067645308431367692126298485986436853296517286808371363530122898655102,
            5142088473072471911606118589373706464436665288086823815032133709745865624239
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            192412090154289126255525008072838818750618231959223808913077431079476100398,
            16680226208175346202125216503320559024519678635305683085048974361828187933388
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            13255093418854792380870578917702241922261796294504941279600084972427577856406,
            16703575946175052280481510150065923938288218492073498409246705985157073172976
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            14611645525146168131546469911134605266105395674367532379573925219284756968850,
            9180841544292970971925283043418912226790382357900720329684734791204008116692
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            2093136127858573989158000008661951321478566089491339721990723862712342044397,
            3479112815391227126555073043607738841577866145428165798857344596723397166740
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            9265812101361681891528018577316767844242460300888563612201061934420432744206,
            5541311564075685085289850938322409280957582885620164738756011054454149332243
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            11227185000719312370366892984986929626067729748321556442189731028449754694770,
            20618965069503270373071578440784095240363773297165481063530953546252469081340
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            4669081079962214354462542864864205995203524249518659189865170300314774624992,
            11624054747847748228814442400217991579529083077042837357124096945020416510830
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            11747681282542406163306431425433825786519870274233725420733915084246168271322,
            7285198581196324597174909789328241043869477293284960371768318289566638032595
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            7283678873544492934726556851032904083655887731065239254466434706297261163961,
            10299104424481045072736078072109918894068600228807506038386942861691794546026
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            7250213099065138574279332055943775148757601762537579444676713552101557013718,
            15144742748533637966956991508382955818634637527902496634486060626755538401491
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
            uint[27] memory input
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
