// The methods of 'asset' in https://github.com/trufflesuite/truffle/blob/develop/packages/resolver/solidity/Assert.sol
const DaoRoyalty = artifacts.require("DaoRoyalty");

contract('DaoRoyalty', (accounts) => {

    it('CASE_D_01 quotaAtLeast', async () => {

        const instance = await DaoRoyalty.new("V123456Z", [accounts[8], accounts[9]], [40, 60], {
            from: accounts[0]
        });

        // take effect direct
        let newValue = web3.utils.toWei("0.02", "ether");
        await instance.setPurchasePrice(newValue, {from: accounts[9]});
        assert.equal(await instance.purchasePrice.call(), newValue);

        // take effect jointly
        await instance.setPriceEarningRatio(4, {from: accounts[9]});
        assert.equal(await instance.priceEarningRatio.call(), 2);
        await instance.setPriceEarningRatio(3, {from: accounts[8]});
        assert.equal(await instance.priceEarningRatio.call(), 2);
        await instance.setPriceEarningRatio(4, {from: accounts[8]});
        assert.equal(await instance.priceEarningRatio.call(), 4);


    });

});

