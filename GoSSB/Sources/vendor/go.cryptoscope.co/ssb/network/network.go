// SPDX-FileCopyrightText: 2021 The Go-SSB Authors
//
// SPDX-License-Identifier: MIT

// Package network implements utilities for dialing and listening to secret-handshake powered muxrpc connections.
package network

import (
	"fmt"
	"net"
)

var privateIPBlocks []*net.IPNet

func init() {
	for _, cidr := range []string{
		"127.0.0.0/8",    // IPv4 loopback
		"10.0.0.0/8",     // RFC1918
		"172.16.0.0/12",  // RFC1918
		"192.168.0.0/16", // RFC1918
		"::1/128",        // IPv6 loopback
		"fe80::/10",      // IPv6 link-local
		"fc00::/7",       // IPv6 unique local addr
	} {
		_, block, _ := net.ParseCIDR(cidr)
		privateIPBlocks = append(privateIPBlocks, block)
	}
}

func isIPv4(ip net.IP) bool {
	return len(ip.To4()) == net.IPv4len
}

func newIPFromNetworkAddress(arg net.Addr) (net.IP, error) {
	switch v := arg.(type) {
	case *net.IPAddr:
		return v.IP, nil
	case *net.IPNet:
		return v.IP, nil
	case *net.TCPAddr:
		return v.IP, nil
	case *net.UDPAddr:
		return v.IP, nil
	default:
		return nil, fmt.Errorf("cannot get IP for network type %s", arg.Network())
	}
}

// associatedIPAddresses returns addresses which listen on that of the
// argument.
func associatedIPAddresses(arg net.Addr) ([]net.Addr, error) {
	ipAddr, err := newIPFromNetworkAddress(arg)
	if err != nil {
		return nil, err
	}
	if ipAddr != nil && !ipAddr.IsUnspecified() {
		return []net.Addr{arg}, nil
	}

	// iterate over all interfaces to get link-local / broadcast addresses
	var ret []net.Addr
	netIfs, err := net.Interfaces()
	if err != nil {
		return nil, err
	}
	for _, netIf := range netIfs {
		if netIf.Flags&net.FlagLoopback != 0 {
			continue
		}

		addrs, err := netIf.Addrs()
		if err != nil {
			return nil, err
		}
		for _, addr := range addrs {
			ipNet, ok := addr.(*net.IPNet)
			if !ok {
				// log.Print("DBG: ignoring non-net", ipNet.String())
				continue
			}
			ipAddr := &net.IPAddr{
				IP: ipNet.IP,
			}
			if !isIPv4(ipAddr.IP) {
				// assume IPv6
				ipAddr.Zone = netIf.Name
			}
			ret = append(ret, ipAddr)
		}
	}

	return ret, nil
}

func isNetworkAddressSiteLocal(addr net.Addr) (bool, error) {
	ipAddr, err := newIPFromNetworkAddress(addr)
	if err != nil {
		return false, err
	}

	var found bool
	for _, block := range privateIPBlocks {
		if block.Contains(ipAddr) {
			found = true
			break
		}
	}
	return found, nil
}

func findSiteLocalNetworkAddresses(arg net.Addr) ([]net.Addr, error) {
	var ret []net.Addr

	associated, err := associatedIPAddresses(arg)
	if err != nil {
		associated = []net.Addr{arg}
	}
	for _, addr := range associated {
		isSiteLocal, err := isNetworkAddressSiteLocal(addr)
		if err != nil {
			return nil, err
		}
		if isSiteLocal {
			ret = append(ret, addr)
		}
	}

	return ret, nil
}

func findNetworkInterfaceByIP(arg net.Addr) (net.Interface, error) {
	ifcs, err := net.Interfaces()
	if err != nil {
		return net.Interface{}, err
	}

	argIP, err := newIPFromNetworkAddress(arg)
	if err != nil {
		return net.Interface{}, err
	}

	for _, ifc := range ifcs {
		addrs, err := ifc.Addrs()
		if err != nil {
			return net.Interface{}, err
		}
		for _, addr := range addrs {
			ifcIP, err := newIPFromNetworkAddress(addr)
			if err != nil {
				continue
			}
			if ifcIP.Equal(argIP) {
				return ifc, nil
			}
		}
	}
	return net.Interface{}, fmt.Errorf("interface for %s not found", arg)
}

func localBroadcastAddress(arg net.Addr) (string, error) {
	ip, err := newIPFromNetworkAddress(arg)
	if err != nil {
		return "", err
	}

	if isIPv4(ip) {
		return net.IPv4bcast.String(), nil
	} else {
		if ip.IsLoopback() {
			return net.IPv6loopback.String(), nil
		}
		ifc, err := findNetworkInterfaceByIP(arg)
		if err != nil {
			return "", err
		}
		return net.IPv6linklocalallnodes.String() + "%" + ifc.Name, nil
	}
}
