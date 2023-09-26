
import { Decimal } from 'decimal.js';
import { BigNumber, BigNumberish } from 'ethers';

interface AnonymityRewardPointsFormulaParams {
    balance: Decimal | string | number | BigNumberish;
    anonymityRewardPoints: Decimal | string | number | BigNumberish;
    poolWeight?: Decimal | string | number | BigNumberish;
}

// a = floor(10**18 * e^(-0.0000000001 * anonymityRewardPoints))
// TNT = BalBefore - (BalBefore * a)/10**18
function anonymityRewardPointsToTNT({ balance, anonymityRewardPoints, poolWeight = new Decimal(1e10) }: AnonymityRewardPointsFormulaParams): BigNumberish {
    const decimals = new Decimal(10 ** 18);
    balance = new Decimal(balance.toString());
    anonymityRewardPoints = new Decimal(anonymityRewardPoints.toString());
    poolWeight = new Decimal(poolWeight.toString());

    const power = anonymityRewardPoints.div(poolWeight).negated();
    const exponent = Decimal.exp(power).mul(decimals);
    const newBalance = balance.mul(exponent).div(decimals);
    return BigNumber.from(balance.sub(newBalance).toFixed(0));
}

export { anonymityRewardPointsToTNT };