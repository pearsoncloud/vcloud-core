module IntegrationHelper

  def self.create_test_case_vapps(number_of_vapps,
                                  vdc_name,
                                  catalog_name,
                                  vapp_template_name,
                                  network_names = [],
                                  prefix = "vcloud-core-tests"
                                 )
    vapp_template = Vcloud::Core::VappTemplate.get(vapp_template_name, catalog_name)
    timestamp_in_s = Time.new.to_i
    base_vapp_name = "#{prefix}-#{timestamp_in_s}-"
    vapp_list = []
    number_of_vapps.times do |index|
      vapp_list << Vcloud::Core::Vapp.instantiate(
        base_vapp_name + index.to_s,
        network_names,
        vapp_template.id,
        vdc_name
      )
    end
    vapp_list
  end

  def self.delete_vapps(vapp_list)
    fsi = Vcloud::Fog::ServiceInterface.new()
    vapp_list.each do |vapp|
      fsi.delete_vapp(vapp.id)
    end
  end

end
