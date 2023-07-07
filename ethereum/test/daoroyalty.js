// The methods of 'asset' in https://github.com/trufflesuite/truffle/blob/develop/packages/resolver/solidity/Assert.sol
const DaoRoyalty = artifacts.require("DaoRoyalty");

contract('DaoRoyalty', (accounts) => {

    it('CASE_D_01 multi_vote', async () => {

        const instance = await DaoRoyalty.new(
            [accounts[8], accounts[9]],
            [40, 60],
            "V123456Z",
            0,
            3,
            {from: accounts[0]}
        );

        // take effect direct
        let newValue = web3.utils.toWei("0.02", "ether");
        await instance.setPurchasePrice(newValue, {from: accounts[9]});
        assert.equal(await instance.purchasePrice.call(), newValue);

        // take effect jointly
        assert.equal(await instance.priceEarningRatio.call(), 3);
        await instance.setPriceEarningRatio(4, {from: accounts[9]});
        assert.equal(await instance.priceEarningRatio.call(), 3);
        await instance.setPriceEarningRatio(3, {from: accounts[8]});
        assert.equal(await instance.priceEarningRatio.call(), 3);
        await instance.setPriceEarningRatio(4, {from: accounts[8]});
        assert.equal(await instance.priceEarningRatio.call(), 4);

        await instance.setPriceEarningRatio(3, {from: accounts[9]});
        assert.equal(await instance.priceEarningRatio.call(), 4);
        await instance.setPriceEarningRatio(2, {from: accounts[9]});
        assert.equal(await instance.priceEarningRatio.call(), 4);
        await instance.setPriceEarningRatio(2, {from: accounts[8]});
        assert.equal(await instance.priceEarningRatio.call(), 2);

    });

});

