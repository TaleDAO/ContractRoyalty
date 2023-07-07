const Tradeable = artifacts.require("Tradeable");

contract('Tradeable', (accounts) => {

    it('CASE_C_01 allow quota', async () => {

        const instance = await Tradeable.new([accounts[8], accounts[9]], [40, 60], {
            from: accounts[0]
        });

        let sum = await instance.sumAllowedQuota.call();
        assert.equal(sum, 0);

        // set allowed quota
        await instance.setAllowedQuota(20, {from: accounts[8]});
        await instance.setAllowedQuota(30, {from: accounts[9]});
        sum = (await instance.sumAllowedQuota.call()).toNumber();
        assert.equal(sum, 50);

        // non-owner setting should raise error
        try {
            await instance.setAllowedQuota(50, {from: accounts[7]});
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.reason, "NOT_ENOUGH");

        // setting too big
        try {
            await instance.setAllowedQuota(50, {from: accounts[8]});
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.reason, "NOT_ENOUGH");

        // ensure cannot be called externally
        try {
            await instance.allocateQuota(accounts[8], accounts[9], 50);
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.toString(), "TypeError: instance.allocateQuota is not a function");

        // a new comer buys 40 quotes, there will be two result:
        // 1. accounts[8] sold 20, accounts[9] sold 20
        // 2. accounts[8] sold 10, accounts[9] sold 30
        let pricePerQuotaBN = await instance.getPricePerQuota.call();
        let priceAtLeastBN = await instance.minPricePerQuota.call();
        assert.isTrue(pricePerQuotaBN >= priceAtLeastBN);

        // execute the investment
        var BN = web3.utils.BN;
        assert(await instance.sumProfit.call(), 0);
        await instance.investAcquireQuota({from: accounts[7], value: pricePerQuotaBN * new BN(40)});
        assert(await instance.sumProfit.call(), 0);
        assert(await instance.getOwnedQuota(accounts[7]), 40);
        assert(await instance.sumAllowedQuota(), 10);

        const quota8 = (await instance.getOwnedQuota(accounts[8])).toNumber();
        const quota9 = (await instance.getOwnedQuota(accounts[9])).toNumber();
        if (quota8 == 20) {
            assert.equal(quota9, 40);
            assert.equal(await instance.getAllowedQuotas(accounts[8]), 0);
            assert.equal(await instance.getAllowedQuotas(accounts[9]), 10);
        }
        else {
            assert.equal(quota8, 30);
            assert.equal(quota9, 30);
            assert.equal(await instance.getAllowedQuotas(accounts[8]), 10);
            assert.equal(await instance.getAllowedQuotas(accounts[9]), 00);
        }
        
        // DEBUG
        console.log("pricePerQuotaBN", pricePerQuotaBN.toString());
        console.log("contractBalance", (await web3.eth.getBalance(instance.address)).toString());
        console.log("quota8", quota8, "quota9", quota9);
        for (let i=7; i<10; i++) {
            const bn = await instance.getBalance.call(accounts[i]);
            console.log(`address[${i}]`, bn.toString());
        }

    });

});

