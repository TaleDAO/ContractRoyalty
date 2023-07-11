const Tradeable = artifacts.require("Tradeable");

contract('Tradeable', (accounts) => {

    var BN = web3.utils.BN;

    it('CASE_C_01 buy & allow & invest', async () => {

        const instance = await Tradeable.new([accounts[8], accounts[9]], [40, 60], {
            from: accounts[0]
        });

        assert.equal(await instance.sumAllowedQuota.call(), 0);

        // set allowed quota
        await instance.setAllowedQuota(20, {from: accounts[8]});
        await instance.setAllowedQuota(30, {from: accounts[9]});
        assert.equal((await instance.sumAllowedQuota.call()).toNumber(), 50);

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
        assert(await instance.sumProfit.call(), 0);
        await instance.investForQuota({from: accounts[7], value: pricePerQuotaBN * new BN(40)});
        assert(await instance.sumProfit.call(), 0);
        assert(await instance.getOwnedQuota(accounts[7]), 40);
        assert(await instance.sumAllowedQuota(), 10);

        const quota8 = (await instance.getOwnedQuota(accounts[8])).toNumber();
        const quota9 = (await instance.getOwnedQuota(accounts[9])).toNumber();
        if (quota8 == 20) {
            assert.equal(quota9, 40);
            assert.equal(await instance.getAllowedQuota(accounts[8]), 0);
            assert.equal(await instance.getAllowedQuota(accounts[9]), 10);
        }
        else {
            assert.equal(quota8, 30);
            assert.equal(quota9, 30);
            assert.equal(await instance.getAllowedQuota(accounts[8]), 10);
            assert.equal(await instance.getAllowedQuota(accounts[9]), 00);
        }

        assert.equal(await instance.getOwnedQuota(accounts[7]), 40);
        assert.equal(await instance.getBalance.call(accounts[7]), 0);
        if (quota8 == 20) {
            assert.equal(await instance.getOwnedQuota(accounts[8]), 20);
            assert.equal(await instance.getOwnedQuota(accounts[9]), 40);
            assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.2", "ether"));
            assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.2", "ether"));
        }
        else {
            assert.equal(await instance.getOwnedQuota(accounts[8]), 30);
            assert.equal(await instance.getOwnedQuota(accounts[9]), 30);
            assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.1", "ether"));
            assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.3", "ether"));
        }

        // 3 purchases
        await instance.receiveFrom([accounts[1], accounts[2], accounts[3]], {from: accounts[0], value: web3.utils.toWei("0.03", "ether")});


        assert.equal(await instance.getBalance.call(accounts[7]), web3.utils.toWei("0.012", "ether"));
        if (quota8 == 20) {
            assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.206", "ether"));
            assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.212", "ether"));
        }
        else {
            assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.109", "ether"));
            assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.309", "ether"));
        }

        assert.equal(await instance.sumAllowedQuota.call(), 10);

    });

});

