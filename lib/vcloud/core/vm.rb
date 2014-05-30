module Vcloud
  module Core
    class Vm
      extend ComputeMetadata

      attr_reader :id

      def initialize(id, vapp)
        unless id =~ /^#{self.class.id_prefix}-[-0-9a-f]+$/
          raise "#{self.class.id_prefix} id : #{id} is not in correct format"
        end
        @id = id
        @vapp = vapp
      end

      def vcloud_attributes
        Vcloud::Fog::ServiceInterface.new.get_vapp(id)
      end

      def update_memory_size_in_mb(new_memory)
        return if new_memory.nil?
        return if new_memory.to_i < 64
        unless memory.to_i == new_memory.to_i
          Vcloud::Fog::ServiceInterface.new.put_memory(id, new_memory)
        end
      end

      def memory
        memory_item = virtual_hardware_section.detect { |i| i[:'rasd:ResourceType'] == '4' }
        memory_item[:'rasd:VirtualQuantity']
      end

      def cpu
        cpu_item = virtual_hardware_section.detect { |i| i[:'rasd:ResourceType'] == '3' }
        cpu_item[:'rasd:VirtualQuantity']
      end

      def name
        vcloud_attributes[:name]
      end

      def href
        vcloud_attributes[:href]
      end

      def update_name(new_name)
        fsi = Vcloud::Fog::ServiceInterface.new
        fsi.put_vm(id, new_name) unless name == new_name
      end

      def vapp_name
        @vapp.name
      end

      def update_cpu_count(new_cpu_count)
        return if new_cpu_count.nil?
        return if new_cpu_count.to_i == 0
        unless cpu.to_i == new_cpu_count.to_i
          Vcloud::Fog::ServiceInterface.new.put_cpu(id, new_cpu_count)
        end
      end

      def update_metadata(metadata)
        return if metadata.nil?
        fsi = Vcloud::Fog::ServiceInterface.new
        metadata.each do |k, v|
          fsi.put_vapp_metadata_value(@vapp.id, k, v)
          fsi.put_vapp_metadata_value(id, k, v)
        end
      end

      def add_extra_disks(extra_disks)
        vm = Vcloud::Fog::ModelInterface.new.get_vm_by_href(href)
        if extra_disks
          extra_disks.each do |extra_disk|
            Vcloud::Core.logger.debug("adding a disk of size #{extra_disk[:size]}MB into VM #{id}")
            vm.disks.create(extra_disk[:size])
          end
        end
      end

      def configure_network_interfaces(networks_config)
        return unless networks_config
        section = {PrimaryNetworkConnectionIndex: 0}
        section[:NetworkConnection] = networks_config.compact.each_with_index.map do |network, i|
          connection = {
              network: network[:name],
              needsCustomization: true,
              NetworkConnectionIndex: i,
              IsConnected: true
          }
          ip_address = network[:ip_address]
          mode = network[:mode]
          if mode.nil? then
            mode = ip_address ? 'MANUAL' : 'DHCP'
          end
          connection[:IpAddress] = ip_address unless ip_address.nil?
          connection[:IpAddressAllocationMode] = mode
          connection
        end
        Vcloud::Fog::ServiceInterface.new.put_network_connection_system_section_vapp(id, section)
      end

      def configure_guest_customization_section(name, bootstrap_config, extra_disks)
        if bootstrap_config.nil? or bootstrap_config[:script_path].nil?
          interpolated_preamble = ''
        else
          preamble_vars = bootstrap_config[:vars] || {}
          preamble_vars.merge!(:extra_disks => extra_disks)
          interpolated_preamble = generate_preamble(
              bootstrap_config[:script_path],
              bootstrap_config[:script_post_processor],
              preamble_vars,
          )
        end
        Vcloud::Fog::ServiceInterface.new.put_guest_customization_section(id, name, interpolated_preamble)
      end

      def generate_preamble(script_path, script_post_processor, preamble_vars)
        erb_vars = OpenStruct.new({
          vapp_name: vapp_name,
          vars: preamble_vars
        })
        erb_vars_binding_object = erb_vars.instance_eval { binding }
        erb_output = interpolate_erb_file(script_path, erb_vars_binding_object)
        if script_post_processor
          post_process_erb_output(erb_output, script_post_processor) if script_post_processor
        else
          erb_output
        end
      end


      def update_storage_profile storage_profile
        storage_profile_href = get_storage_profile_href_by_name(storage_profile, @vapp.name)
        Vcloud::Fog::ServiceInterface.new.put_vm(id, name, {
          :StorageProfile => {
            name: storage_profile,
            href: storage_profile_href
          }
        })
      end

      private

      def interpolate_erb_file(erb_file, binding_object)
        ERB.new(File.read(File.expand_path(erb_file)), nil, '>-').result(binding_object)
      end

      def post_process_erb_output(data_to_process, post_processor_script)
        # Open3.capture2, as we just need to return STDOUT of the post_processor_script
        Open3.capture2(
          File.expand_path(post_processor_script),
          stdin_data: data_to_process).first
      end

      def virtual_hardware_section
        vcloud_attributes[:'ovf:VirtualHardwareSection'][:'ovf:Item']
      end

      def get_storage_profile_href_by_name(storage_profile_name, vapp_name)
        q = Vcloud::Core::QueryRunner.new
        vdc_results = q.run('vApp', :filter => "name==#{vapp_name}")
        vdc_name = vdc_results.first[:vdcName]

        q = Vcloud::Core::QueryRunner.new
        sp_results = q.run('orgVdcStorageProfile', :filter => "name==#{storage_profile_name};vdcName==#{vdc_name}")

        if sp_results.empty? or !sp_results.first.has_key?(:href)
          raise "storage profile not found"
        else
          return sp_results.first[:href]
        end
      end

      def self.id_prefix
        'vm'
      end

    end

  end
end
