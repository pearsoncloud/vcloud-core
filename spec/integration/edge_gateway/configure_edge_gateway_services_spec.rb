require 'spec_helper'

module Vcloud
  module Core
    describe EdgeGateway do

      required_env = {
        'VCLOUD_EDGE_GATEWAY' => 'to name of VSE',
      }

      error = false
      required_env.each do |var,message|
        unless ENV[var]
          puts "Must set #{var} #{message}" unless ENV[var]
          error = true
        end
      end
      Kernel.exit(2) if error

      it "configures a firewall service" do
        configuration = {
            :FirewallService =>
                {
                    :IsEnabled => "true",
                    :DefaultAction => "allow",
                    :LogDefaultAction => "false",
                    :FirewallRule =>
                        [
                            {
                                :Id => "999",
                                :IsEnabled => "false",
                                :MatchOnTranslate => "false",
                                :Description => "generated from edge_gateway_tests",
                                :Policy => "drop",
                                :Protocols => {:Tcp => "true"},
                                :Port => "3412",
                                :DestinationPortRange => "3412",
                                :DestinationIp => "internal",
                                :SourcePort => "3412",
                                :SourcePortRange => "3412",
                                :SourceIp => "internal",
                                :EnableLogging => "false"
                            }
                        ]
                }
        }
        edge_gateway = EdgeGateway.get_by_name(ENV['VCLOUD_EDGE_GATEWAY'])
        edge_gateway.update_configuration(configuration)

        actual_config = edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
        actual_config[:FirewallService].should == configuration[:FirewallService]
      end

      it "configures a load balancer service" do
        network_1        = ENV['VCLOUD_NETWORK1_NAME']
        network_1_id     = ENV['VCLOUD_NETWORK1_ID']
        load_balancer_ip = ENV['VCLOUD_LOAD_BALANCER_IP']

        configuration = {
            :LoadBalancerService =>
                {
                    :IsEnabled => "true",
                    :Pool =>
                      [
                        {
                          :Name           =>   "Test pool",
                          :Description    =>   "Generated from edge_gateway integration tests",
                          :ServicePort    =>
                            [
                              {
                                :IsEnabled        => "true",
                                :Protocol         => "HTTP",
                                :Algorithm        => "ROUND_ROBIN",
                                :Port             => "80",
                                :HealthCheckPort  => "",
                                :HealthCheck      =>
                                  {
                                    :Mode               => "HTTP",
                                    :Uri                => "/",
                                    :HealthThreshold    => "2",
                                    :UnhealthThreshold  => "3",
                                    :Interval           => "5",
                                    :Timeout            => "15",
                                  }
                              },
                              {
                                :IsEnabled        => "true",
                                :Protocol         => "HTTPS",
                                :Algorithm        => "ROUND_ROBIN",
                                :Port             => "443",
                                :HealthCheckPort  => "",
                                :HealthCheck      =>
                                  {
                                    :Mode               => "SSL",
                                    :Uri                => "",
                                    :HealthThreshold    => "2",
                                    :UnhealthThreshold  => "3",
                                    :Interval           => "5",
                                    :Timeout            => "15",
                                  }
                              },
                              {
                                :IsEnabled        => "true",
                                :Protocol         => "TCP",
                                :Algorithm        => "ROUND_ROBIN",
                                :Port             => "999",
                                :HealthCheckPort  => "",
                                :HealthCheck      =>
                                  {
                                    :Mode               => "TCP",
                                    :Uri                => "",
                                    :HealthThreshold    => "2",
                                    :UnhealthThreshold  => "3",
                                    :Interval           => "5",
                                    :Timeout            => "15",
                                  }
                              }
                            ],
                          :Member         =>
                            [
                              {
                                :IpAddress   => "10.10.10.10",
                                :Weight      => "1",
                                :ServicePort =>
                                  [
                                    {
                                      :Protocol => "HTTP",
                                      :Port     => "",
                                      :HealthCheckPort => "",
                                    },
                                    {
                                      :Protocol => "HTTPS",
                                      :Port     => "",
                                      :HealthCheckPort => "",
                                    },
                                    {
                                      :Protocol => "TCP",
                                      :Port     => "",
                                      :HealthCheckPort => "",
                                    }
                                  ]
                              }
                            ],
                            :Operational  => "false",
                          }
                        ],
                    :VirtualServer  =>
                      [
                        {
                          :IsEnabled      => "true",
                          :Name           => "Test virtual server",
                          :Description    => "Test virtual server",
                          :Interface      =>
                              {
                                :type => "application/vnd.vmware.vcloud.orgVdcNetwork+xml",
                                :name => network_1,
                                :href => "https://api.vcd.portal.skyscapecloud.com/api/admin/network/" + network_1_id,
                              },
                          :IpAddress      => load_balancer_ip,
                          :ServiceProfile =>
                            [
                              {
                                :IsEnabled    => "true",
                                :Protocol     => "HTTP",
                                :Port         => "80",
                                :Persistence  =>
                                  {
                                      :Method => "",
                                  }
                              },
                              {
                                :IsEnabled    => "false",
                                :Protocol     => "HTTPS",
                                :Port         => "443",
                                :Persistence  =>
                                  {
                                      :Method => "",
                                  }
                              },
                              {
                                :IsEnabled    => "false",
                                :Protocol     => "TCP",
                                :Port         => "999",
                                :Persistence  =>
                                  {
                                      :Method => "",
                                  }
                              }
                            ],
                          :Logging => "false",
                          :Pool => "Test pool",
                        }
                      ]
                }
        }
        edge_gateway = EdgeGateway.get_by_name(ENV['VCLOUD_EDGE_GATEWAY'])
        edge_gateway.update_configuration(configuration)

        # Modify our input configuration slightly to match the configuration we're expecting
        expected_config = configuration
        expected_config[:LoadBalancerService][:Pool][0][:Operational] = "false"

        actual_config = edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
        actual_config[:LoadBalancerService].should == configuration[:LoadBalancerService]
      end

      it "configures a NAT 'service'" do
        network_1            = ENV['VCLOUD_NETWORK1_NAME']
        network_1_id         = ENV['VCLOUD_NETWORK1_ID']
        provider_network     = ENV['VCLOUD_PROVIDER_NETWORK_NAME']
        provider_network_ip  = ENV['VCLOUD_PROVIDER_NETWORK_IP']
        provider_network_id  = ENV['VCLOUD_PROVIDER_NETWORK_ID']
        network_1_nat_ip     = ENV['VCLOUD_NETWORK1_NAT_IP']
        dnat_rule_id         = ENV['VCLOUD_DNAT_RULE_ID']
        snat_rule_id         = ENV['VCLOUD_SNAT_RULE_ID']

        configuration = {
            :NatService =>
                {
                    :IsEnabled => "true",
                    :NatRule   =>
                      [
                        {
                          :Id             => snat_rule_id,
                          :RuleType       => "SNAT",
                          :IsEnabled      => "true",
                          :GatewayNatRule =>
                          {
                            :Interface =>
                                {
                                  :type => "application/vnd.vmware.admin.network+xml",
                                  :name => provider_network,
                                  :href => "https://api.vcd.portal.skyscapecloud.com/api/admin/network/" + provider_network_id,
                                },
                                :OriginalIp   => network_1_nat_ip,
                                :TranslatedIp => provider_network_ip,
                          }
                        },
                        {
                          :Id             => dnat_rule_id,
                          :RuleType       => "DNAT",
                          :IsEnabled      => "true",
                          :GatewayNatRule =>
                          {
                            :Interface =>
                                {
                                  :type => "application/vnd.vmware.admin.network+xml",
                                  :name => provider_network,
                                  :href => "https://api.vcd.portal.skyscapecloud.com/api/admin/network/" + provider_network_id,
                                },
                                :OriginalIp     => provider_network_ip,
                                :OriginalPort   => "80",
                                :TranslatedIp   => network_1_nat_ip,
                                :TranslatedPort => "999",
                                :Protocol       => "tcp"
                          }
                        }
                      ]
                }
        }
        edge_gateway = EdgeGateway.get_by_name(ENV['VCLOUD_EDGE_GATEWAY'])
        edge_gateway.update_configuration(configuration)

        actual_config = edge_gateway.vcloud_attributes[:Configuration][:EdgeGatewayServiceConfiguration]
        actual_config[:NatService].should == configuration[:NatService]
      end
    end
  end
end
