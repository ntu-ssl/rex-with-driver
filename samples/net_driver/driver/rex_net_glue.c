// SPDX-License-Identifier: GPL-2.0
//
// C ABI shim for the Rex virtual network driver.
//
// The kernel is built with kCFI (CONFIG_CFI=y). Every *indirect* call through a
// C function pointer — e.g. `dev_hard_start_xmit()` calling
// `net_device_ops->ndo_start_xmit` — verifies that the target carries the kCFI
// type-id clang computed for that exact C signature. A Rust `extern "C" fn`
// assigned straight into `ndo_start_xmit` fails this check because
// `ndo_start_xmit` returns `netdev_tx_t` (a C `enum`), which bindgen flattens to
// a plain `c_int` on the Rust side; rustc's kCFI id for an `int` return differs
// from clang's id for the `enum` return, so the indirect call traps with an
// "invalid opcode".
//
// These thin C trampolines are compiled by clang, so they carry the correct
// kCFI ids and are safe to store in `net_device_ops`. They forward to the Rust
// transmit logic via a *direct* call (direct calls are not kCFI-checked).

#include <linux/netdevice.h>
#include <linux/etherdevice.h>

// Implemented in rex_net_main.rs (`#[no_mangle]`). Direct call: not kCFI-checked.
int rex_net_xmit_rs(struct sk_buff *skb, struct net_device *dev);

// The Rust module references this symbol and passes it to alloc_netdev_mqs()
// as the setup callback.
void rex_net_setup(struct net_device *dev);

static int rex_net_open(struct net_device *dev)
{
	netif_carrier_on(dev);
	netif_start_queue(dev);
	return 0;
}

static int rex_net_stop(struct net_device *dev)
{
	netif_stop_queue(dev);
	netif_carrier_off(dev);
	return 0;
}

static netdev_tx_t rex_net_xmit(struct sk_buff *skb, struct net_device *dev)
{
	// rex_net_xmit_rs consumes the skb and returns NETDEV_TX_OK (0).
	return (netdev_tx_t)rex_net_xmit_rs(skb, dev);
}

static const struct net_device_ops rex_net_ops = {
	.ndo_open = rex_net_open,
	.ndo_stop = rex_net_stop,
	.ndo_start_xmit = rex_net_xmit,
};

void rex_net_setup(struct net_device *dev)
{
	ether_setup(dev);
	dev->netdev_ops = &rex_net_ops;
	eth_hw_addr_random(dev);
}
