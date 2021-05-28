#!/usr/bin/env bash
set -eu

main() {
    case "${script_type:-}" in
        '')
            declare netns=''
            declare -a opts=()
            while (( $# )); do
                case "$1" in
                    --namespace)
                        if (( $# < 2 )); then
                            echo 'Options error: missing value: namespace' >&2
                            exit 1
                        fi
                        netns="$2"
                        shift
                        ;;
                    *)
                        opts+=("$1")
                        ;;
                esac
                shift
            done
            if [[ -z "${netns}" ]]; then
                echo 'Options error: missing parameter: namespace' >&2
                exit 1
            fi
            # don't do the cleanup from openvpn with '--down $0' because the script will be executed as nobody:nobody with insufficient permissions to delete the network namespace
            trap "cleanup ${netns@Q}" EXIT
            openvpn --ifconfig-noexec --route-noexec --script-security 2 --setenv netns "${netns}" --up "$0" --route-up "$0" "${opts[@]}"
            ;;
        up)
            # stop openvpn if script fails
            trap 'kill "${daemon_pid}"' ERR

            mkdir -p "/etc/netns/${netns}"
            rm -f "/etc/netns/${netns}/resolv.conf"

            ip netns add "${netns}"
            ip -n "${netns}" link set dev lo up
            ip link set dev "${dev}" up netns "${netns}" mtu "${tun_mtu}"

            if [[ -n "${ifconfig_local:-}" ]]; then
                if [[ -n "${ifconfig_remote:-}" ]]; then
                    ip -n "${netns}" -4 addr add local "${ifconfig_local}" peer "${ifconfig_remote}/${ifconfig_netmask:-30}" ${ifconfig_broadcast:+broadcast "${ifconfig_broadcast}"} dev "${dev}"
                else
                    ip -n "${netns}" -4 addr add local "${ifconfig_local}/${ifconfig_netmask:-30}" ${ifconfig_broadcast:+broadcast "${ifconfig_broadcast}"} dev "${dev}"
                fi
            fi

            if [[ -n "${ifconfig_ipv6_local:-}" ]]; then
                if [[ -n "${ifconfig_ipv6_remote:-}" ]]; then
                    ip -n "${netns}" -6 addr add local "${ifconfig_ipv6_local}" peer "${ifconfig_ipv6_remote}/${ifconfig_ipv6_netbits:-112}" dev "${dev}"
                else
                    ip -n "${netns}" -6 addr add local "${ifconfig_ipv6_local}/${ifconfig_ipv6_netbits:-112}" dev "${dev}"
                fi
            fi

            declare -a domains=()
            for (( i = 1; 1; i++ )); do
                declare -n option="foreign_option_$i"
                if [[ -z "${option:-}" ]]; then
                    break
                fi
                declare -a params=(${option})
                case "${params[0]}:${params[1]}" in
                    dhcp-option:DNS)
                        echo "nameserver ${params[2]}" >> "/etc/netns/${netns}/resolv.conf"
                        ;;
                    dhcp-option:DOMAIN)
                        domains+=("${params[2]}")
                        ;;
                esac
            done
            if [[ -n "${domains[*]}" ]]; then
                echo "domain ${domains[0]}" >> "/etc/netns/${netns}/resolv.conf"
                echo "search ${domains[*]}" >> "/etc/netns/${netns}/resolv.conf"
            fi
            ;;
        route-up)
            trap 'kill "${daemon_pid}"' ERR

            for (( i = 1; 1; i++ )); do
                declare -n net="route_network_$i"
                declare -n mask="route_netmask_$i"
                declare -n gw="route_gateway_$i"
                declare -n mtr="route_metric_$i"
                if [[ -z "${net:-}" ]]; then
                    break
                fi
                ip -n "${netns}" -4 route add "${net}/${mask}" via "${gw}" ${mtr:+metric "${mtr}"}
            done

            if [[ -n "${route_vpn_gateway:-}" ]]; then
                ip -n "${netns}" -4 route add default via "${route_vpn_gateway}"
            fi

            for (( i = 1; 1; i++ )); do
                declare -n net="route_ipv6_network_$i"
                declare -n gw="route_ipv6_gateway_$i"
                if [[ -z "${net:-}" ]]; then
                    break
                fi
                ip -n "${netns}" -6 route add "${net}" via "${gw}" metric 128
            done

            if [[ -n "${ifconfig_ipv6_remote:-}" ]]; then
                ip -n "${netns}" -6 route add default via "${ifconfig_ipv6_remote}" metric 256
            fi
            ;;
    esac
}

cleanup() {
    ip netns delete "$1"
    rm -f "/etc/netns/$1/resolv.conf"
    rmdir --ignore-fail-on-non-empty "/etc/netns/$1"
}

main "$@"
