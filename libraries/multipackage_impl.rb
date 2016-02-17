class MultipackageMash < BasicObject
  def initialize
    @__object = {}
  end

  def []=(key, value)
    @__object[key] = value
  end

  def [](key)
    @__object[key]
  end

  def method_missing(sym, *args)
    @__object[sym] = ( args.length == 1 ? args[0] : args )
  end
end

module MultipackageDefinitionImpl
  def multipackage(name, &block)
    params = get_params(&block)
    params[:name] = name
    multipackage_definition_impl(params)
  end

  def multipackage_install(name, &block)
    Chef::Log.deprecation(
      "The `multipackage_install` definition is deprecated, just use `multipackage` from now on"
    )
    params = get_params(&block)
    params[:name] = name
    params[:action] = :install
    multipackage_definition_impl(params)
  end

  def multipackage_remove(name, &block)
    Chef::Log.deprecation(
      "The `multipackage_install` definition is deprecated, just use `multipackage` from now on"
    )
    params = get_params(&block)
    params[:name] = name
    params[:action] = :remove
    multipackage_definition_impl(params)
  end

  def get_params(&block)
    params = MultipackageMash.new
    params.instance_eval(&block) if block_given?
    params
  end

  def multipackage_definition_impl(params)
    # @todo make sure package_names and versions have the same # of items
    # (unless verison is omitted)
    package_names = []
    if params[:package_name] || params[:name]
      package_names = [params[:package_name] || params[:name]].flatten
    end
    versions = [params[:version]].flatten if params[:version]
    options = params[:options]
    timeout = params[:timeout]
    action = params[:action] || :install

    t = begin
          resources(:multipackage_internal => "collected packages #{action}")
        rescue Chef::Exceptions::ResourceNotFound
          multipackage_internal "collected packages #{action}" do
            package_name Array.new
            version Array.new
            action action
          end
        end

    package_names.each_with_index do |package_name, i|
      if t.package_name.include?(package_name)
        # supress CHEF-3694 errors and be more useful about warning if there's only a reason
        if options
          Chef::Log.warn "ignoring options #{options} set on duplicated package #{package_name}"
        end
        if timeout
          Chef::Log.warn "ignoring timeout #{timeout} set on duplicated package #{package_name}"
        end
        next
      end
      t.package_name.push(package_name)
      if versions
        t.version.push versions[i]
      else
        # keep the version array matching the package_name array
        t.version.push nil
      end
    end

    t.options(options) if options
    t.timeout(timeout) if timeout

    t
  end
end

Chef::Recipe.send(:include, MultipackageDefinitionImpl)