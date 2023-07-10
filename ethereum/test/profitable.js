const Profitable = artifacts.require("Profitable");


contract('Profitable', (accounts) => {

    var BN = web3.utils.BN;

    const isValueInRange = (val, min, max) => {
        val = new BN(val);
        min = new BN(min);
        max = new BN(max);
        return min < val && val < max;
    }

    it('CASE_B_01 buy & withdraw', async () => {

        const instance = await Profitable.new([accounts[8], accounts[9]], [40, 60], {
            from: accounts[0]
        });

        // buy singly from the customers
        await web3.eth.sendTransaction({
            from: accounts[0],
            to: instance.address,
            value: (await instance.purchasePrice()).toString()
        })

        // buy in batches from the broker
        const value = web3.utils.toWei("0.03", "ether");
        await instance.receiveFrom([accounts[1], accounts[2], accounts[3]], {from: accounts[0], value});

        // check the balance
        assert.equal(await web3.eth.getBalance(instance.address), web3.utils.toWei("0.04", "ether"))

        // owner1 withdraws
        assert.equal(await instance.getBalance.call(accounts[8]), web3.utils.toWei("0.016", "ether"));
        await instance.withdraw({from: accounts[8]});
        assert.isTrue(isValueInRange(
            await web3.eth.getBalance(accounts[8]),
            web3.utils.toWei("100.015", "ether"),
            web3.utils.toWei("100.016", "ether")
        ));
        assert.equal(await web3.eth.getBalance(instance.address), web3.utils.toWei("0.024", "ether"));
        assert.equal(await instance.getBalance.call(accounts[8]), 0);

        // malicious non-owner withdraw
        try {
            await instance.withdraw({from: accounts[0]});
        } catch(err) {
            raiseError = err
        }
        assert.equal(raiseError.reason, "NOTHING_WITHDRAW");

        // owner2 withdraws
        await instance.withdraw({from: accounts[9]});
        assert.isTrue(isValueInRange(
            await web3.eth.getBalance(accounts[9]),
            web3.utils.toWei("100.023", "ether"),
            web3.utils.toWei("100.024", "ether")
        ));
        assert.equal(await web3.eth.getBalance(instance.address), 0);

        // owner2 withdraws again
        await instance.withdraw({from: accounts[9]});
        assert.isTrue(isValueInRange(
            await web3.eth.getBalance(accounts[9]),
            web3.utils.toWei("100.023", "ether"),
            web3.utils.toWei("100.024", "ether")
        ));
        assert.equal(await web3.eth.getBalance(instance.address), 0);

    });

});

