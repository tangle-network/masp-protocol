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
				11399092544416986267805282113222192475385137396396425427381642386000936404558,
				12222371727282010696933949267957236252070141580629210317082174683758450706076
			],
			[
				3979483960612574396028255085707380978736922062454483621884614204004754628127,
				4429453702215748084961539401708202178258243074467966094965139544733522469449
			]
		);
		vk.IC = new Pairing.G1Point[](32);

		vk.IC[0] = Pairing.G1Point(
			21529938270789042185901257442971635937212206418338535580822490124940393404177,
			8749352087303191103148740695332345543042139194550416896897501163413552029795
		);

		vk.IC[1] = Pairing.G1Point(
			17299387157148082980199996129423133782302020872873075486276760933025741258766,
			17879962246127606034784438671804948803268234603874326047458025569307839815188
		);

		vk.IC[2] = Pairing.G1Point(
			7184540182655593882687832774128859203712782999809080399215805496103772462136,
			9228518425344871159005160751316900176527130997778881445272436542610646967637
		);

		vk.IC[3] = Pairing.G1Point(
			2186407013224859308353353893260888825587402660428977016383544308533230101892,
			20259782457827422728829486335994015794044314456561749817671902465743041486807
		);

		vk.IC[4] = Pairing.G1Point(
			3649943052038514840066486396644471162148309039370908387618946039951216355358,
			14222196722234076269189640549871524634397643535115051756095625559580586131954
		);

		vk.IC[5] = Pairing.G1Point(
			20377195111022075606415946797119836256349423272504166762645186769205747911739,
			10256501554433600801775047797285928041646970178955326897510351900631784017138
		);

		vk.IC[6] = Pairing.G1Point(
			15881621761676272464889080563795004187430427165875935980513113354562124486498,
			9426568329118005909806328257234642746841480213294695911408164360387953698328
		);

		vk.IC[7] = Pairing.G1Point(
			3812460723869975926370946146703803609524611158219178384606128665883824353607,
			11184004837544737262688056170624999745062385784767029444295490234993486202856
		);

		vk.IC[8] = Pairing.G1Point(
			4252048601186267452145583821888972592298088185223806048982740519903133257345,
			15767950615569608513967407232231926028463971856067595515137824435401022580081
		);

		vk.IC[9] = Pairing.G1Point(
			2659576797307505083287257434251276249322755348460386601003243978830108986734,
			5414972934248370832530815682150432727935675349866578629187489908438025931877
		);

		vk.IC[10] = Pairing.G1Point(
			21572714345853361262717515074609962571663456415303963178410858964083967112646,
			8752252730705025552338610361691901186859991059919258573325303323627704517053
		);

		vk.IC[11] = Pairing.G1Point(
			1389794848939409631526281475694484253674641158392929839455826548795243880551,
			3976987855027813551537996928864645079407019574811988016565655207013457280315
		);

		vk.IC[12] = Pairing.G1Point(
			17500260114726757590499245360022238232171051445099579151129254429077107359880,
			18577773903140819179044936935695219750346185934695607037603133752337729151502
		);

		vk.IC[13] = Pairing.G1Point(
			12695795179501742658993009571184452739637702602995613581928064819267168675240,
			13232085374358265527464856012962828074386177427862127736984712808305411446680
		);

		vk.IC[14] = Pairing.G1Point(
			17794290965827604442668911769866757780431162373646937351249142536593393087599,
			13558006810512763897243495404534159071061550727579855716506121162793105215769
		);

		vk.IC[15] = Pairing.G1Point(
			21710441914675757187660400698850239842878678199923314420418551207434412768769,
			19236163548110591193556542713837117952855774248919204823076297766314295234389
		);

		vk.IC[16] = Pairing.G1Point(
			19288374081004903661210357384217193575491236616530066115689352798300315113170,
			957134768669207029752791691961737308032471709793892267901835075333246234039
		);

		vk.IC[17] = Pairing.G1Point(
			15479538761469710578867350496431112483227707172388360771208237407294398517109,
			14270231840367291961494114903569350139095922629510715369290560556745299986411
		);

		vk.IC[18] = Pairing.G1Point(
			6665892773455335984797950006300072516369090726196598419465858461673519736698,
			17710417009835658646570384632449883899620395609408955809084220005627236401049
		);

		vk.IC[19] = Pairing.G1Point(
			12558112622124611825179081529991825177504399895266132931922402549840535389353,
			3112866820415990790614091183305299487419982870926837898638659090344751908969
		);

		vk.IC[20] = Pairing.G1Point(
			912404682037584515795632061694359454536443653620423510843961921744060585558,
			16167239246797380829965587180003617736557485310661260361700574686488222635557
		);

		vk.IC[21] = Pairing.G1Point(
			4334390612222429315858721813628418868856594568798926874845645389356987889627,
			8018466160041137265865294214509277346146234607910960578965904165666463703171
		);

		vk.IC[22] = Pairing.G1Point(
			14470483587212319961467981147067154993145042853107181771592486588069619316999,
			21452982196203435811985599561121605332526340982150236557208013068912072080967
		);

		vk.IC[23] = Pairing.G1Point(
			5417619112503385041057566558879192253775914193602471129170200559492292472707,
			17408116321425160035210178337372630610273837467656926076293659080079361702349
		);

		vk.IC[24] = Pairing.G1Point(
			5590034582439535490374887080455298371576769406736536377655600938795277416730,
			8217628201336088499575375903939642063815671001940725577863625846830704079513
		);

		vk.IC[25] = Pairing.G1Point(
			6674459020653396655734963283299233973963230277440171004978998055499749991809,
			10609343482408330436288131234159071146818473187002290839993012488002848565058
		);

		vk.IC[26] = Pairing.G1Point(
			11446957167972864367599921957580182097476351568062849062914352214038799476305,
			7502389034629779025429668475533774308255007344674975738777169031350733147831
		);

		vk.IC[27] = Pairing.G1Point(
			6770168091462054573341033271991163763339154102490347234559386656230115324372,
			13933324622143928015146330159169929662048667201561179248968186132629266037775
		);

		vk.IC[28] = Pairing.G1Point(
			17497529925281257444543954918852551627567498918169739517697132631132119906727,
			769932454945285636929933388719728962503466664066653419255656565609412305623
		);

		vk.IC[29] = Pairing.G1Point(
			537314586422851719569729239963521568793739543056057241995204989190218616841,
			20507173789361689372530741398818082106729726348111577999330191305504816846210
		);

		vk.IC[30] = Pairing.G1Point(
			15066867348029770443821758456052614646754623004938492866004181010864803358936,
			9445778888567484244932261505089830777118797374101098242323832554848510821044
		);

		vk.IC[31] = Pairing.G1Point(
			7676814161739918775166828911711647434631131353932980814541633715949860918084,
			17634019524006623692853963443324875607005032212807647649613464407234230396652
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
		uint[31] memory input
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
