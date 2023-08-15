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
				16217894682834652417137063744597978047957689958168545048262737438957935153236,
				12544549722096138353847601148947164352101917208007378405501549413447100744490
			],
			[
				20143868737325255127884028093962520322653806354793088395080318746388159875257,
				3539857003053115063980585717290725111281102232937187105466770559623433126835
			]
		);
		vk.IC = new Pairing.G1Point[](26);

		vk.IC[0] = Pairing.G1Point(
			3532581242654944361915597131968865727090616725588092941173129719732624649914,
			7937182791297643856503752611994116443716978047978395679067389516661031098271
		);

		vk.IC[1] = Pairing.G1Point(
			15914030210041752070130157356303689017535866390674529820350808477602049653944,
			14750235189570902581895356122528582097803283492294094215897317326388748052372
		);

		vk.IC[2] = Pairing.G1Point(
			1158464422850108431722890104972790999907260666747916299062838958979771120687,
			2010765132846467217522417846014034857541303719314527950636298219993783626512
		);

		vk.IC[3] = Pairing.G1Point(
			20515307715863546396416436237412446390338877129435868569118768604375836364709,
			354361749093092959844804957625070571700488233140212254954498232925592401640
		);

		vk.IC[4] = Pairing.G1Point(
			21526291940887547505229804303211773721927461338989129440033298781506218351899,
			12303602850069621236415841660091705016185116291905747310708411395570745208093
		);

		vk.IC[5] = Pairing.G1Point(
			17194766623188301206462149636165097969333977725444907329533292088601612386800,
			17139993961672053773238849525357522912521715570593689549602721886528497118812
		);

		vk.IC[6] = Pairing.G1Point(
			6933468561235524527501850525779813068631468899871349925266482422440642402152,
			1787963547191574614031418581448178275365362245273730796669335076815096229508
		);

		vk.IC[7] = Pairing.G1Point(
			6322140988269909224785368785430262611713110318005811690917722629006193991213,
			17855771981717833766554552522094490327284570520082067521387180010143422490314
		);

		vk.IC[8] = Pairing.G1Point(
			20643095767687246852374382474334357215132351398198918231176701612326134799306,
			18354232281588010481814146695650175524528000783216329882047325752799001436133
		);

		vk.IC[9] = Pairing.G1Point(
			12922079696433724386226853465596199019866296828184113482413557769480657018286,
			9693621069221218242269474694730966666092135678226177201797768681577958518285
		);

		vk.IC[10] = Pairing.G1Point(
			17136141928786692495642086896015140048239372826796968732401600771143718602667,
			8107793852763300799498214219193131252424885288811271159235342416420635574188
		);

		vk.IC[11] = Pairing.G1Point(
			3628804457139875460675912140627348641775567086672661421745137799771764874234,
			12695984721715027709656258565568457226538495865735140609740393176019310438739
		);

		vk.IC[12] = Pairing.G1Point(
			145924275385507677029111661311035980064061500614116837524085525078768563057,
			13778294818777225709958475609547524512414358924565289264088623469329164963132
		);

		vk.IC[13] = Pairing.G1Point(
			11572310780039692283547127412094099571284271374476418527666620704697583755630,
			7286596724387137797975493086678974687963668987330476455856592436913396165045
		);

		vk.IC[14] = Pairing.G1Point(
			5153337402067925545973581441138090271243721326687467897226010303605172428943,
			19182333432917782080601776611534024757565721809710311640292077816969059274377
		);

		vk.IC[15] = Pairing.G1Point(
			13061804633708873388554959320674811991152119707789581834912454667270834272602,
			423868187240232933204888570568188457973483670302811469386620296973890366840
		);

		vk.IC[16] = Pairing.G1Point(
			19139077644232514946660114890976904769723624338073753594969777941691811893153,
			1883761234003953344450699613949824379941292220025285679371364568173380132664
		);

		vk.IC[17] = Pairing.G1Point(
			10835045542655969270553645907730694317292719305508862395809183604782320386663,
			2413958351170009085636051919408918230294883550571756643244924013648305783870
		);

		vk.IC[18] = Pairing.G1Point(
			3619874781912135969630349445173258532190287894869859394276203473270763447092,
			21103890720119437204754254000938850675117746127604337164781665652995981350878
		);

		vk.IC[19] = Pairing.G1Point(
			18308155704142644611124915972098035959629841694667974085436702261440521260900,
			19272074147825089375565343489038391216241993261825097580943331879604426424407
		);

		vk.IC[20] = Pairing.G1Point(
			20553009882333669583518727403771911607583051205023452233052451972801541756893,
			18357760675865996298834985524525128862292084500803962873575775533239093064797
		);

		vk.IC[21] = Pairing.G1Point(
			12786666154491301656884861501403932986323160282908132770703441795775919450707,
			16211237969041731355488983818946779155314986373910753294141867536697308107428
		);

		vk.IC[22] = Pairing.G1Point(
			15754343545949673098741736391330161083854193849740886857712877804404581610800,
			7521851035851542519153255842117808782912758504054398521580326655236966338081
		);

		vk.IC[23] = Pairing.G1Point(
			4564695110347356923736628295507380076870855582014455151317692092491634415423,
			7145012764266383612519406830619546802356559725366932577397208476173195069222
		);

		vk.IC[24] = Pairing.G1Point(
			12471284650693381406941780999402698279493210526874367421315292449719515563057,
			4645507471283986849371469524275744897964859870841437944081136060736790693358
		);

		vk.IC[25] = Pairing.G1Point(
			8757699861680610985626908884637275355196795865770444586272355995876514251391,
			15807310660178254841423642093504546708878513400081182723482327998353771571954
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
		uint[25] memory input
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
