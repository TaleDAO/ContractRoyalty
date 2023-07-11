const Tradeable = artifacts.require("Tradeable");

contract('Tradeable', (accounts) => {

    var BN = web3.utils.BN;

    const isValueInRange = (val, min, max) => {
        val = new BN(val);
        min = new BN(min);
        max = new BN(max);
        return min < val && val < max;
    }

    it('CASE_C_02 gift & withdraw', async () => {

        const instance = await Tradeable.new([accounts[8], accounts[9]], [40, 60], {
            from: accounts[0]
        });

        // 3 purchases
        await instance.receiveFrom([accounts[1], accounts[2], accounts[3]], {from: accounts[0], value: web3.utils.toWei("0.03", "ether")});

        await instance.setAllowedQuota(20, {from: accounts[8]});
        await instance.setAllowedQuota(20, {from: accounts[9]});
        assert.equal((await instance.sumAllowedQuota.call()).toNumber(), 40);

        // new investor
        let pricePerQuotaBN = await instance.getPricePerQuota.call();
        await instance.investForQuota({from: accounts[7], value: pricePerQuotaBN * new BN(40)});
        assert.equal((await instance.sumAllowedQuota.call()).toNumber(), 0);

        assert.equal(await instance.getBalance.call(accounts[7]), 0);
        assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.212", "ether"));
        assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.218", "ether"));

        // gift away quota
        await instance.setAllowedQuota(20, {from: accounts[8]});
        await instance.giftAwayQuota(accounts[7], 10, {from: accounts[8]});

        assert.equal(await instance.getBalance.call(accounts[7]), 0);
        assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.212", "ether"));
        assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.218", "ether"));
        assert.equal((await instance.sumAllowedQuota.call()).toNumber(), 10);
        assert.equal((await instance.getAllowedQuota.call(accounts[8])).toNumber(), 10);

        assert.equal(await instance.getOwnedQuota.call(accounts[7]), 50);
        assert.equal(await instance.getOwnedQuota.call(accounts[8]), 10);
        assert.equal(await instance.getOwnedQuota.call(accounts[9]), 40);

        // gift more, accounts[8] is no longer owner, but the balance remained can still be withdrawn at first time
        await instance.giftAwayQuota(accounts[7], 10, {from: accounts[8]});
        assert.equal(await instance.getBalance.call(accounts[7]), 0);
        assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.212", "ether"));
        assert.equal(await instance.getBalance.call(accounts[9]), web3.utils.toWei("0.218", "ether"));
        assert.equal((await instance.getAllowedQuota.call(accounts[8])).toNumber(), 0);
        assert.equal(await instance.getOwnedQuota.call(accounts[8]), 0);

        assert.isTrue(new BN(await web3.eth.getBalance(accounts[8])).cmp(new BN(web3.utils.toWei("100", "ether"))) < 0);
        await instance.withdraw({from: accounts[8]});
        assert.isTrue(new BN(await web3.eth.getBalance(accounts[8])).cmp(new BN(web3.utils.toWei("100.21", "ether"))) > 0);

        // but will raise at second time
        try {
            await instance.withdraw({from: accounts[8]});
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.reason, "NOTHING_WITHDRAW");

        // withdraw can make it clear
        await instance.withdraw({from: accounts[9]});
        assert.isTrue(isValueInRange(
            await web3.eth.getBalance(accounts[9]),
            web3.utils.toWei("100.20", "ether"),
            web3.utils.toWei("100.218", "ether")
        ));

        assert.equal(await web3.eth.getBalance(instance.address), 0);
    });

});

