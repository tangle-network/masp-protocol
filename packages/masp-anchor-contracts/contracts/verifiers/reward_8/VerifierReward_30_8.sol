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
				5262820150570007181695444524192469186743825167781962647692459290703734435694,
				6356603183983046826407171488927036159258381192367867340672194628608346736698
			],
			[
				2711869719430913591347579487099457953661303328626856827396774016780749484240,
				17237665192726100449092867884360032809289696591140369481440832357406405984424
			]
		);
		vk.IC = new Pairing.G1Point[](31);

		vk.IC[0] = Pairing.G1Point(
			13597573233280736201701612635611774363537440510220591997997666680222497490267,
			20563331022586314826043282642370054578932078954227366511057138357811968467892
		);

		vk.IC[1] = Pairing.G1Point(
			1601260111837889058647929387803973818241116127218056909221539636537512511710,
			4297913580087772871333970969817112077648525228720366797591855563728461432873
		);

		vk.IC[2] = Pairing.G1Point(
			14293762080526977302156635648196978676754086242889604558382743105184428722083,
			8231280503214694971361144391230217060171674518537901761873192141275880429167
		);

		vk.IC[3] = Pairing.G1Point(
			20062669973104128641058771755930203541076536250035086761919421979319160979483,
			17335036300794877627163600987154947169510416263028212027778218564441013680879
		);

		vk.IC[4] = Pairing.G1Point(
			15642507459726380478142196466380387775236746880456691481694070860642032078156,
			761460985158253837312414233712753998966099334762221590127639654720328376071
		);

		vk.IC[5] = Pairing.G1Point(
			5666757253389373097007395598231249347450970229535552655291611737029059344521,
			5751474609697090023621082596141901077439618797777375258830967793142912842912
		);

		vk.IC[6] = Pairing.G1Point(
			21336769085594421343884904309063143789013946764513706658376194878836154465264,
			20393285920708135735027234552248498282496099129003746711136205997400407055447
		);

		vk.IC[7] = Pairing.G1Point(
			19732429255468940038499266559378143516806785970933264446144441989410868660320,
			12657701544536465092051803215886289081250910407823627128597702089355856088850
		);

		vk.IC[8] = Pairing.G1Point(
			12938894695482915724191494390120801534166227578234696682294925673375044999261,
			10241677757054756103602678836789335261745504914755282345739412285363264063632
		);

		vk.IC[9] = Pairing.G1Point(
			7546448575366720380296912916301053735295916145189433027069870776313179612051,
			18639672422753179401563523130638504362330189078296953439893251877041564666753
		);

		vk.IC[10] = Pairing.G1Point(
			16582649084388670706198360515687709116644288840404970658611683133332145678301,
			16045461647810730213689725048193345930229604197966332176178884408731527129137
		);

		vk.IC[11] = Pairing.G1Point(
			16394861907920696060040494879249378998878250713181112687980950712472670740873,
			15511890124654969616065430977193812973696299575331922898003611235237758679497
		);

		vk.IC[12] = Pairing.G1Point(
			5588352152802037051240871154003888062169777871875609680619268007778398637948,
			16227305228689093115462879569450012224607148144703495997418603255000105847361
		);

		vk.IC[13] = Pairing.G1Point(
			16362956004610165635441958644664060710462805643614863472055385991980672051763,
			10236782092711173198894758000448371904810245037716982801347754517139618168095
		);

		vk.IC[14] = Pairing.G1Point(
			7263849748714154551191315811427080630099199014752348890423758881416054878683,
			10639712788078221370202666224762795541559484586149903075052565554389202005302
		);

		vk.IC[15] = Pairing.G1Point(
			2910640204575842261807283031167730646292882329718209547733118039198402408061,
			14380458898348224900597487855130623174872757555630972498454122785040533779237
		);

		vk.IC[16] = Pairing.G1Point(
			1489050827897703059189834163816308959898260037994095442440162177557168932580,
			14231855181876160549392749911030258612427643277149774578221602001151035918790
		);

		vk.IC[17] = Pairing.G1Point(
			4112320394178393256575602019596664913688970942068850407792289635002353022599,
			17759645948304011594275454898617416019498934680210968505280700597983223837836
		);

		vk.IC[18] = Pairing.G1Point(
			1688422978065585890182418309786979810592747962054728238456178553741063143552,
			1337311462863511250026416859907083896390835964187868198923478831521074672393
		);

		vk.IC[19] = Pairing.G1Point(
			8772629479778024645750676175909922623573488756683819644420513278415760748415,
			12456714162369628633473383511235264925318498697847855938444534768044748868869
		);

		vk.IC[20] = Pairing.G1Point(
			796980072106665396707484415101367399319104218525923509580102908968522460219,
			7094764657125253516515390281531332790815685882803189847054132386851717838914
		);

		vk.IC[21] = Pairing.G1Point(
			21266178010588086806625797183369961508137243522176780746287682820383905958639,
			12486161050011063873702859054698575694069507394047992447139010546036517248733
		);

		vk.IC[22] = Pairing.G1Point(
			20151851793915263016535618401129146710527459515396735051781437603078038492636,
			18268291622289925860303082008689673497527770407500386017972688065064956345854
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
		uint[30] memory input
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
