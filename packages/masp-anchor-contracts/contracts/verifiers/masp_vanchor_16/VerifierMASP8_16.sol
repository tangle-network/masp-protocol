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
contract VerifierMASP8_16 {
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
            [7082700191701783441124771718153418404731383691062850144144863503022354146848,
             10689629535243859257340773689609307341036865578211466587761598760261727249316],
            [19521793407540303492629112921620160042400187660822683108079300669444962343401,
             13221637019617046433828992344308900035971098232071384179806636306269817236875]
        );
        vk.IC = new Pairing.G1Point[](46);
        
        vk.IC[0] = Pairing.G1Point( 
            4762223811620475938640906701820484841077298592634070498712391195675850411444,
            6429049589062343167072615846330701478534933354977764465282826225233910417311
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            11001439875370379330427057062787604006169816029181540864627777049058464046305,
            11867798089086137590889218518016917037122906931671736002614756072879079272281
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            21647420952671245252654703519110558998896571793243919631970129746277231398126,
            17643100975279227829427836209731356514687791276396755172698717923764239136862
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            583817175043501673658089282788801108652759744814507292166989363955235323785,
            2555807500223050058225882551927657188142609930581469906756079854303859961177
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            8033780025041850183700879500180352218953210639056051594699123860994318448665,
            8641306515096468633011056269222510149717114238544713405916010328106435895652
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            17068743539425307335898315342236496224026031624820362279409443797728912886915,
            14479833388492918106841647273147377247477482301978677816141112546809427074428
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            6893626327357241175235346740373314550935926063620999520632502075736803763882,
            6589097114041872398752826122537680186927091382512435009589405318184399533964
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            11266543094486836294175228661514346604520583510838902985341276319896005268575,
            21033481437225339319225969995582026968738076226632479439240698155260549978040
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            14385129411733493657369381196054162332284484526089720513621720883336660151814,
            2440719570350410674758591263531232093818523326688155656577442352872955558723
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            17141821470543166792106659110029850152738582497920895206814711034481687286079,
            13244157504407783416397653186674281953963745123648674269433573013796874155456
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            12813908119371643985351811808832757758298584777180604303915915376103948852646,
            9167016067271752997879597612490180082134362619577958628719857998715299692740
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            16685904742056367816633572099410259527914519260181195605260949788346443816717,
            12624037405991879155955344200559117640781234623413037704249150479245671832940
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            3309600105010851462886730931587042223024632269138861387759830561211277234318,
            956943583249502986701302844091341509174656256092796033519246354579684385142
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            9283237817882502040022910130151708935369753312100695577892079214205460021370,
            9274561065311474361451638250447577691555569021884425346599887997695772720023
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            14173311167927256070615154640072210903527794570916603849246899201983867247259,
            3201639259571477870560984928535122132830659444525291166381070569480179292040
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            19345754434088410368972481016798331765551643755463819013876963838443387492951,
            10050387280859833753546604090444209945649063459107212616960226433311632414254
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            10242039256566641528486700396419401245227650630459344160113634974878089698708,
            14758876950346558469504592581551293991734331421170679062718816933804161385398
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            8657673671977843248184470662697439041366206194104635230405826997487421995155,
            20178320117334048156656107524759630196903878151633257289665045415839732006367
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            14628707608850774356078751193140500174056965350944619081740129414298510036889,
            11974580343425828347608316706084422843426242723070110079670793803006898016901
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            1927351732126238234768946199218545437474611972440814202651275745611927272735,
            5858286403006141988275469397754955174677479945468445989371658629605996574396
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            7869144830549168628198651297555144388954743069068243466124944078192745519293,
            7725905746108798399932820648452197508451265343488302496275628310348283649529
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            9963528531801700495460657830068991091065769850581597126994419778188307082158,
            18986209030576015436244990705174183868370155044092352441495544099318291973461
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            18806331122085951361495982883795106678989031735456127351668487432575087398015,
            6258278807930366874578092136414449984773031709762246772694087668758922128196
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            9271032799070162619455486931743575815463210514670492733497349627327843253746,
            12813228728196579090812946800361897399869815049543961498819289458912495509996
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            10531593775470980956019489579393312330260464823112899846821503324860581581011,
            8859503722761918067077275730235394625887297767063577952678791748873742776527
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            6507941733352611068636553979165581802118930085752294905813275124832913308047,
            18848662579444859141255704871313849662091625017080644606204090423851972063848
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            15167976922931070739166381282720813039792053341149352042222114814755834078193,
            11936823048608531955686362140887569560208043184593177005572287334636974904233
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            14183525345834274407499355913709456996667004722121369363659708197892990757018,
            4593325992168000134629997098891639345847795130495518724162400564623082210207
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            9644448463899042318647263874403461017274739279979455748326457020647373593196,
            1905906709469324585040204630742244019864543115445210005648320039604344633716
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            10389478472400674164960040273236266056619456440141757993578229125707725972689,
            8749398947032648965643315536385980500799669557959473218377420062821404450425
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            1056516820502077752662651372295215008600754067162271133296510324070136183740,
            21465091959482773305696258458703313614888928799115864857358192389691099781275
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            10718503726043734552903315073177483283953151677599778801295790906954942463495,
            14344135746843245922970601237593216184090965076490400413999930874679370788758
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            10869149970513524346841693643290876976211497007221236070511059289531339215039,
            8098574415950822872942784620677734258838551694410236516945451313117569687432
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            937999954703550533679467873652664031812506249647413497854713198903746736399,
            12361638467666383111061714712797257524650066377094285602866360436031358597338
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            21306132654725649863802276848916355096107726756425983577533645105805476023083,
            10781981094972737565460627100895353927744339377816039757443281082493813848046
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            3330739342321310422841482291089867676969759196131413472700339079591139977604,
            18655182230623393306261138756265561134950969316583918079688809864169156038388
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            21835233968259439703843928184314485074027343167446235136420024661234900068571,
            13317900125559357293648261880586507702580592316643581533921775288479019608862
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            1058508230231256849530893879467198635497376520705028670665682109555615897411,
            16681193751371172364602980333949650006618906968471393184362673770272883376664
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            7324169661336419547290022101177167254587403298548482875182061178948460479071,
            12843926329094788367830938535109187480168530336838104536540256553158461516610
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            5858610592700249810526282149393263125330254176959720780219452367826304272292,
            7436461210464980928124374474518529815335412257601680931920352534586341541410
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            10821354786971765241988943956712900040734028369419559058069157300063832233043,
            12032008237211045512023360015996417658625461320450027292067780950300866668931
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            13556649632849415911815348352076619215339170740442419762191991295135381001795,
            2229017206497707438719561503527561639755496350006799572869312301683009948871
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            4429348889411040181964258908849740045367577707671135299864944249670056074192,
            20696323993794107798334416457187322423858657028517517263498146764252599009597
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            8264652753697294992113810983060668356058340286812337820605343828186701430625,
            4481867165785983000601040512285552733229026961290785063743741569916049411727
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            14490845373963716411058368314484760606673645531055497442137789126983685740772,
            16278803356865261998047990767864465316268367755382051456065179272392538086870
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            17222989763989598156411929965861219677589924178080489489985459931114393007147,
            10583251672408945498590941670253163066255208765963877038080951985164299103818
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
            uint[45] memory input
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
