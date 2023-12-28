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
		return
			G2Point(
				[
					11559732032986387107991004021392285783925812861821192530917403151452391805634,
					10857046999023057135944570762232829481370756359578518086990519993285655852781
				],
				[
					4082367875863433681332203403145435568316851327593401208105741076214120093531,
					8495653923123431417604973247489272438418190587263600148770280649306958101930
				]
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
		if (p.X == 0 && p.Y == 0) return G1Point(0, 0);
		return G1Point(p.X, q - (p.Y % q));
	}

	/// @return r the sum of two points of G1
	function addition(
		G1Point memory p1,
		G1Point memory p2
	) internal view returns (G1Point memory r) {
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
			switch success
			case 0 {
				invalid()
			}
		}
		require(success, "pairing-add-failed");
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
			switch success
			case 0 {
				invalid()
			}
		}
		require(success, "pairing-mul-failed");
	}

	/// @return the result of computing the pairing check
	/// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
	/// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
	/// return true.
	function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
		require(p1.length == p2.length, "pairing-lengths-failed");
		uint elements = p1.length;
		uint inputSize = elements * 6;
		uint[] memory input = new uint[](inputSize);
		for (uint i = 0; i < elements; i++) {
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
			success := staticcall(
				sub(gas(), 2000),
				8,
				add(input, 0x20),
				mul(inputSize, 0x20),
				out,
				0x20
			)
			// Use "invalid" to make gas estimation work
			switch success
			case 0 {
				invalid()
			}
		}
		require(success, "pairing-opcode-failed");
		return out[0] != 0;
	}

	/// Convenience method for a pairing check for two pairs.
	function pairingProd2(
		G1Point memory a1,
		G2Point memory a2,
		G1Point memory b1,
		G2Point memory b2
	) internal view returns (bool) {
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
		G1Point memory a1,
		G2Point memory a2,
		G1Point memory b1,
		G2Point memory b2,
		G1Point memory c1,
		G2Point memory c2
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
		G1Point memory a1,
		G2Point memory a2,
		G1Point memory b1,
		G2Point memory b2,
		G1Point memory c1,
		G2Point memory c2,
		G1Point memory d1,
		G2Point memory d2
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
			[
				4252822878758300859123897981450591353533073413197771768651442665752259397132,
				6375614351688725206403948262868962793625744043794305715222011528459656738731
			],
			[
				21847035105528745403288232691147584728191162732299865338377159692350059136679,
				10505242626370262277552901082094356697409835680220590971873171140371331206856
			]
		);
		vk.gamma2 = Pairing.G2Point(
			[
				11559732032986387107991004021392285783925812861821192530917403151452391805634,
				10857046999023057135944570762232829481370756359578518086990519993285655852781
			],
			[
				4082367875863433681332203403145435568316851327593401208105741076214120093531,
				8495653923123431417604973247489272438418190587263600148770280649306958101930
			]
		);
		vk.delta2 = Pairing.G2Point(
			[
				17461239406110019544848063777568729034296856653761909804938727553380925410858,
				16552459707995199011467533066074644728730307464093223358639660239302219406614
			],
			[
				11018950083148685229987824807478994444873239966077691797144999520236172565791,
				2008100464854656521734534599145207293496627423169012060192352244210812015312
			]
		);
		vk.IC = new Pairing.G1Point[](40);

		vk.IC[0] = Pairing.G1Point(
			1903912385381818871513544544218993987076569300975201314401256271641881457346,
			14035496493458408536177991606665220700739985689415620446467902107704141571267
		);

		vk.IC[1] = Pairing.G1Point(
			6293542275438812388244444638219657035809242627309745145595518994251635229943,
			19175505325099873080416295561538259583258992405167171524064885539724663473962
		);

		vk.IC[2] = Pairing.G1Point(
			6985940510680927394224769779868849785174540378527363587397722172052183454363,
			2776911601023936053596629068011585749094971413795463813740342320654744285891
		);

		vk.IC[3] = Pairing.G1Point(
			14697085545622917759582990013319242494974656753493574374408352790300129327757,
			7857093833832605227687727853263854365116527135361466681869896193493546679535
		);

		vk.IC[4] = Pairing.G1Point(
			12766138381639039105089912101113881010673130607220307967153179201649985582750,
			6306196340164315163593809238088205264430277067615597637989039605854490171864
		);

		vk.IC[5] = Pairing.G1Point(
			13870795748503950272512955458583676307359653345193587842045524283990725380967,
			2243665901240400156191379488968750710861027568649348056466851675694660893706
		);

		vk.IC[6] = Pairing.G1Point(
			9142772285096808192323123725539123296041512162491617454301557211088609007246,
			18297304868013532202608491586137725728937497674644078875120264294126949280830
		);

		vk.IC[7] = Pairing.G1Point(
			19482137354685643010993789184725086755906240441447612557582072897621146229116,
			5775209023804291658123326960434584677650701837152727863502022782839647661783
		);

		vk.IC[8] = Pairing.G1Point(
			11812778455092769346928693390302206344567653236522263596633389308441797495056,
			369215160042036882869013721751857556720661230743999300488679461896299924754
		);

		vk.IC[9] = Pairing.G1Point(
			1662043642204362191960648906519518901785605515666027051774493814660210774544,
			12692440258431448600084369418617576618356425745644615345052593925953093731165
		);

		vk.IC[10] = Pairing.G1Point(
			5267369669057159827154358388918964325309209243445291910171445023948876570072,
			8172690802442416716234145436482339327544934449678880139540044084710573147563
		);

		vk.IC[11] = Pairing.G1Point(
			4430434222680426476748591826164481271157154456056973207989406721249621288929,
			11123464561319918613649156460488262508851910410046209101395020829969402096692
		);

		vk.IC[12] = Pairing.G1Point(
			8075446396722840837690654349547775042244020505783657383875828578424040258947,
			3948002700157436207961387552607554747580832383649460490132888983867457731502
		);

		vk.IC[13] = Pairing.G1Point(
			4600155067339694588880069808676962511070440342487091900194173706268040953698,
			21759725879700234639963895451056550762156584771555708470049902268046878075233
		);

		vk.IC[14] = Pairing.G1Point(
			8304517989025037340515886492284827353142087125487388029774989979360947945189,
			20304889694953991585024750533646055706722963952340122108398731327043522495344
		);

		vk.IC[15] = Pairing.G1Point(
			11542545305728736631835522991463667986574366412518999733976459655193349239560,
			19860427225143045832975330376866996695376186459656315752130285655735664422247
		);

		vk.IC[16] = Pairing.G1Point(
			12693333865206713417910445679370379389978166005586668870274107392272794368293,
			2014280784904776908121085766311296997899125662721549081179083949061611577946
		);

		vk.IC[17] = Pairing.G1Point(
			7549866424708400781816908791120967261003489465826855881500866199079169679110,
			17329368271435762866116781964895614373260073646266762320691114339652032510474
		);

		vk.IC[18] = Pairing.G1Point(
			14888219640734910736405812479865687705218461133776898574995812733354045834215,
			17488308873944953486214957042029257999843107116653277404494092057034298119160
		);

		vk.IC[19] = Pairing.G1Point(
			6804512775922207211183790206470960328079373481782935428479108830312698333884,
			13293551127413032114259881663889646990551371728711108226073528770090829349476
		);

		vk.IC[20] = Pairing.G1Point(
			4651117856791151607457033249653547351627256190161595000954001401469728330712,
			12766020534890908649981996576134276689665603777991078258357867435579941897108
		);

		vk.IC[21] = Pairing.G1Point(
			11062301894709171419987286784759066579412536570631022241078119494327874129843,
			3125440744618131860161656005869101819668257059513765882009101904197875909369
		);

		vk.IC[22] = Pairing.G1Point(
			12131213834330499679094967417476748366184238115847076184533517136606315545130,
			7645668221720483041541444450373056921051768576796345161680180142160846749642
		);

		vk.IC[23] = Pairing.G1Point(
			13392031184370698192642804267220923245143771266500130205112758806778574237045,
			5385780066989782453503446003704268018501249125162263884705819014733300719105
		);

		vk.IC[24] = Pairing.G1Point(
			12742014732764522063378583129983302173448211475015352404462711436206193132948,
			1967562843079624441120951971749892195379785435581128438583580985667625106407
		);

		vk.IC[25] = Pairing.G1Point(
			6105524044600611792900373854862143018553769939350963283390031518079579556764,
			16015563025836225694228353329882789822842995696053392856013541429602369043844
		);

		vk.IC[26] = Pairing.G1Point(
			2986398296966071055572951514542657152717306063276158743528987179139956876282,
			5526829767772538639708949049244024273337933158142392911881794584620300563642
		);

		vk.IC[27] = Pairing.G1Point(
			20674441088662662385998055503132886749204517011338347418674352998182396262108,
			9369558814930100296219884610419978473492639707348947361170987138087568942733
		);

		vk.IC[28] = Pairing.G1Point(
			13153300455124565235692328176326338521022840833420463390666529746965711329886,
			14383482797608340605020523783208763591619357187366047144461033076838954886644
		);

		vk.IC[29] = Pairing.G1Point(
			1576988390423290140520296498752514039318935167793663102438007368984576508783,
			21324713849984041204699899769070435704794501848578120275006953961700539832086
		);

		vk.IC[30] = Pairing.G1Point(
			7905279705320873552352620044156666427166072714622674205525239545007458768891,
			14998091830928145637706397952703475402489502946333440543387119745311649871657
		);

		vk.IC[31] = Pairing.G1Point(
			21248238607437175530113625918926851864589876146763193061971766230657915152868,
			1950414716126520838684975188158063707074286142318195330795391054596430080129
		);

		vk.IC[32] = Pairing.G1Point(
			5545183259369644246705672292763600849390956827623500719839318443479594655681,
			10362083948575875827232199030725862058535730671081678249822774584445686531173
		);

		vk.IC[33] = Pairing.G1Point(
			8277529014273553412944193589794628995195134615582420603079442935878289299606,
			15719818935570289175767800104592228594944565744238095644504718592836018658456
		);

		vk.IC[34] = Pairing.G1Point(
			17064366069081976590032013672366888995907242008338709426216290787984797248074,
			7470932789740810189934336335013421237691154289152895029205738377935637345471
		);

		vk.IC[35] = Pairing.G1Point(
			10673874304210449788370480771226543482371491918540214591695475109386532482172,
			12419059130968458808965299369871455890334344282214583775207748333943146483052
		);

		vk.IC[36] = Pairing.G1Point(
			6413769362340802854093716961651482651330419890154977312385613785177541173119,
			20909997039432207746625852358964907176525237231339998345603837898422476728596
		);

		vk.IC[37] = Pairing.G1Point(
			19573985860055898497614667847119425786610641570055445549459575642245848530971,
			11018409437939813068023870113534431101596482870038065452286198512196066647332
		);

		vk.IC[38] = Pairing.G1Point(
			12539965568032890979894921119416423996776758077319419881508940096464008952632,
			21834606415922188970383038852703343375067205572195179906166430670178098255131
		);

		vk.IC[39] = Pairing.G1Point(
			7946597622462767901812044115917367048063888041519531264077369877415372343885,
			15819944879151260261368196453713624205174434546850384939923594069980605752491
		);
	}

	function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
		uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
		VerifyingKey memory vk = verifyingKey();
		require(input.length + 1 == vk.IC.length, "verifier-bad-input");
		// Compute the linear combination vk_x
		Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
		for (uint i = 0; i < input.length; i++) {
			require(input[i] < snark_scalar_field, "verifier-gte-snark-scalar-field");
			vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
		}
		vk_x = Pairing.addition(vk_x, vk.IC[0]);
		if (
			!Pairing.pairingProd4(
				Pairing.negate(proof.A),
				proof.B,
				vk.alfa1,
				vk.beta2,
				vk_x,
				vk.gamma2,
				proof.C,
				vk.delta2
			)
		) return 1;
		return 0;
	}

	/// @return r  bool true if proof is valid
	function verifyProof(
		uint[2] memory a,
		uint[2][2] memory b,
		uint[2] memory c,
		uint[39] memory input
	) public view returns (bool r) {
		Proof memory proof;
		proof.A = Pairing.G1Point(a[0], a[1]);
		proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
		proof.C = Pairing.G1Point(c[0], c[1]);
		uint[] memory inputValues = new uint[](input.length);
		for (uint i = 0; i < input.length; i++) {
			inputValues[i] = input[i];
		}
		if (verify(inputValues, proof) == 0) {
			return true;
		} else {
			return false;
		}
	}
}