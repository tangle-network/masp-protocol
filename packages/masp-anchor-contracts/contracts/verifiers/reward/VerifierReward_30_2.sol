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
				17693824879409625951909264860377198386043635335618874007683791778018586365583,
				12056708436693886794148542645732622382701957499189351779251848295855144069361
			],
			[
				11856457802877669670989355348613865868710772982616776666221003709322433286769,
				6963906846424725094487462719170853142948436005557188009629206343341977089104
			]
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
			19730639002844700229841555242755801679642879363584725365012344199286674821507,
			4981991493416781626549068965829693541802290871836365422815565459353721699869
		);

		vk.IC[4] = Pairing.G1Point(
			9775517457589981012861190236031385688174134959930209102413124937089233891947,
			16196079515767246307984808967860688345809703573256697711216496456865171794284
		);

		vk.IC[5] = Pairing.G1Point(
			8551256815033302041685998022193625102540531701887994626958694231964203174345,
			943682364861241988992006689963198205997824379982397057266968922052243123443
		);

		vk.IC[6] = Pairing.G1Point(
			595718810805693715629110058959860423911642535758577254608751162265117818742,
			4810919458463438300300309627911458643662710104508459787327913734991794737289
		);

		vk.IC[7] = Pairing.G1Point(
			11909218272042209744320903533724279201345464666460386431621457310794143240162,
			8991045875104155733733118013265098245937584260703194638849118944119638366284
		);

		vk.IC[8] = Pairing.G1Point(
			533196448985370945622457923055612869728094286368341132199683677197220943635,
			17066050629372727496551926342479131692183287084930865641389516883437738481310
		);

		vk.IC[9] = Pairing.G1Point(
			8134057940021477269032479782702440934241908304725173034421590117459770514729,
			15708566785594756986659834487346527732927791403075294060930223223360952170880
		);

		vk.IC[10] = Pairing.G1Point(
			9587891957952742882989927500674930045313198546133727788454462513713994005962,
			10458103092284300585644129956113033374729896313066702708886550282962812334233
		);

		vk.IC[11] = Pairing.G1Point(
			6369654747367833461329018570136846094718918133010767158054197781631610587514,
			3764559843503680302911263792762710240691004860506923743282051752453725938429
		);

		vk.IC[12] = Pairing.G1Point(
			14782571947981128581884437522513483335154805094201355952845775542132944529508,
			10011168824283073702686282543390763544070034693977848109035061773779843635926
		);

		vk.IC[13] = Pairing.G1Point(
			21146949669500788223962972421255922921631761116735046956910369438114271806886,
			4255465251219826617920440168710490132514027127874234514283955212352259161759
		);

		vk.IC[14] = Pairing.G1Point(
			1541855043417089430533447919490566800833470199610878514414942826637005826898,
			18497460146954242862552842486524771322161044307786551244653320642973265945541
		);

		vk.IC[15] = Pairing.G1Point(
			14753396309634295892734600008715285566302208289213454966619662075930758343863,
			8698645048060239214754428593020668610154787499633211301529645273708043369907
		);

		vk.IC[16] = Pairing.G1Point(
			10217866985047476275738972361506816597900529512287286117023088991347941009110,
			4291703433602366481006764688682372505712366263745635092615959771217692625980
		);

		vk.IC[17] = Pairing.G1Point(
			3465542353773928790030104868243523726147075501165218257357190113149548364046,
			4413582933525879950972168174089369751012915919051843878728957570238965901851
		);

		vk.IC[18] = Pairing.G1Point(
			14142650482119954563756900073789742968379678758269714950368198709387906314716,
			20612805174526222827752410909730804502473342130589181103394066382972537396991
		);

		vk.IC[19] = Pairing.G1Point(
			10961139779515381252492191725460837091960307394720059173599739153888937853465,
			18234171299639232209459506133104791823951128342534707171841857666705701000895
		);

		vk.IC[20] = Pairing.G1Point(
			598479477580345943416901738620716303837899440316099928677769179782073910461,
			20626161027207482458320160819908565389313002601923184991628532316285100934921
		);

		vk.IC[21] = Pairing.G1Point(
			11788110690385898170675775539577953933513663521828361884735848218305289945026,
			1986353971949933170313419382298905563366735707723008455988848169422677359505
		);

		vk.IC[22] = Pairing.G1Point(
			24709482024687560408463734244512074583314255719559094188887731089889866500,
			8819399735216595849347148417459632344528207679946613738131311140192390133429
		);

		vk.IC[23] = Pairing.G1Point(
			17658395416140145318211439813986871736310383034941085471077086475398081403632,
			3355570710118623155875476510818610168963243163270990255561950703867118174287
		);

		vk.IC[24] = Pairing.G1Point(
			268916727746987942139060504252323902253153521757050260431320331886334323648,
			20153357863522452667153381297781943160918337083218969988141250871336937947478
		);

		vk.IC[25] = Pairing.G1Point(
			13459794750275528160901937347596519657259835986793483011591094093578389003632,
			419261072003973671593613731767720944104779285549395628333434071647894542592
		);

		vk.IC[26] = Pairing.G1Point(
			16043068888406478477515476477598977069273709339512110700151023507297586476177,
			14536157208390053341043123384270567232019256967704387466461633296972127773896
		);

		vk.IC[27] = Pairing.G1Point(
			18536660426657142999076556419422872000361599294825057209974328907846817978811,
			4260315249231336918765184139033848033657428236794554698174628258768375899337
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
		uint[27] memory input
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
