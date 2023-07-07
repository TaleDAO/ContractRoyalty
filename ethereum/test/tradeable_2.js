const Tradeable = artifacts.require("Tradeable");

contract('Tradeable', (accounts) => {

    var BN = web3.utils.BN;

    it('CASE_C_02 purchase_invest', async () => {

        const instance = await Tradeable.new([accounts[8], accounts[9]], [40, 60], {
            from: accounts[0]
        });

        // 3 readers purchase
        await instance.receiveFrom([accounts[1], accounts[2], accounts[3]], {from: accounts[0], value: web3.utils.toWei("0.03", "ether")});

        await instance.setAllowedQuota(20, {from: accounts[8]});
        await instance.setAllowedQuota(20, {from: accounts[9]});
        assert.equal((await instance.sumAllowedQuota.call()).toNumber(), 40);
        let pricePerQuotaBN = await instance.getPricePerQuota.call();
        await instance.investAcquireQuota({from: accounts[7], value: pricePerQuotaBN * new BN(40)});
        assert.equal((await instance.sumAllowedQuota.call()).toNumber(), 0);

        assert.equal(await instance.getBalance.call(accounts[7]), 0);
        assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.212", "ether"));
        assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.218", "ether"));
    });

});

