require 'json'
require 'sequel'
require 'byebug'
require 'dotenv/load'

class SimpleCrudApp
  def initialize
    @db = Sequel.connect(ENV['DATABASE_URL'])
    @items = @db[:items]
    @categories = @db[:categories]
  end

  def call(env)
    req = Rack::Request.new(env)
    return unauthorized unless authenticated?(req)

    puts "Request #{req.request_method}"
    puts "Request path #{req.path_info}"

    if req.request_method == 'GET' && req.path_info =~ %r{/items/?}
      get_items(req)
    elsif req.request_method == 'GET' && req.path_info =~ %r{/items/\d+}
      get_item(req)
    elsif req.request_method == 'POST' && req.path_info =~ %r{/items/?}
      create_item(req)
    elsif req.request_method == 'PUT' && req.path_info =~ %r{/items/\d+}
      update_item(req)
    elsif req.request_method == 'DELETE' && req.path_info =~ %r{/items/\d+}
      delete_item(req)
    elsif req.request_method == 'GET' && req.path_info =~ %r{/categories/?}
      get_categories(req)
    elsif req.request_method == 'GET' && req.path_info =~ %r{/categories/\d+}
      get_category(req)
    elsif req.request_method == 'POST' && req.path_info =~ %r{/categories/?}
      create_category(req)
    elsif req.request_method == 'PUT' && req.path_info =~ %r{/categories/\d+}
      update_category(req)
    elsif req.request_method == 'DELETE' && req.path_info =~ %r{/categories/\d+}
      delete_category(req)
    else
      not_found
    end
  end

  private

  def get_items(_req)
    items = @items.all
    [200, { 'content-type' => 'application/json' }, [items.to_json]]
  end

  def get_item(req)
    id = req.path_info.split('/').last.to_i
    item = @items.where(id: id).first
    if item
      [200, { 'content-type' => 'application/json' }, [item.to_json]]
    else
      not_found
    end
  end

  def create_item(req)
    params = JSON.parse(req.body.read)
    errors = validate_item(params)
    return [422, { 'content-type' => 'application/json' }, [errors.to_json]] unless errors.empty?

    category = @categories.where(id: params['category_id']).first

    if category
      item_id = @items.insert(name: params['name'], price: params['price'], category_id: params['category_id'])
      created_item = @items.where(id: item_id).first
      [201, { 'content-type' => 'application/json' }, [created_item.to_json]]
    else
      [422, { 'content-type' => 'text/plain' }, ['Invalid category_id']]
    end
  end

  def update_item(req)
    puts "Updating item #{req.path_info}"
    id = req.path_info.split('/').last.to_i
    item = @items.where(id: id).first
    if item.count > 0
      params = JSON.parse(req.body.read)
      errors = validate_item(params)
      return [422, { 'content-type' => 'application/json' }, [errors.to_json]] unless errors.empty?
      
      updated_data = params.merge(updated_at: Time.now)
      if @items.where(id: id).update(updated_data)
        updated_item = @items.where(id: id).first
        [200, { 'content-type' => 'application/json' }, [updated_item.to_json]]
      else
        [422, { 'content-type' => 'text/plain' }, ["Item with id #{id} not updated"]]
      end
    else
      not_found
    end
  end

  def delete_item(req)
    id = req.path_info.split('/').last.to_i
    if @items.where(id: id).delete > 0
      [200, { 'content-type' => 'text/plain' }, ["Item with id #{id} deleted"]]
    else
      not_found
    end
  end

  def get_categories(_req)
    categories = @categories.all
    [200, { 'content-type' => 'application/json' }, [categories.to_json]]
  end

  def get_category(req)
    id = req.path_info.split('/').last.to_i
    category = @categories.where(id: id).first
    if category
      [200, { 'content-type' => 'application/json' }, [category.to_json]]
    else
      not_found
    end
  end

  def create_category(req)
    params = JSON.parse(req.body.read)
    category_id = @categories.insert(name: params['name'])
    created_category = @categories.where(id: category_id).first
    [201, { 'content-type' => 'application/json' }, [created_category.to_json]]
  end

  def update_category(req)
    id = req.path_info.split('/').last.to_i
    category = @categories.where(id: id)
    if category.count > 0
      params = JSON.parse(req.body.read)
      category.update(params.merge(updated_at: Time.now))
      updated_category = category.first
      [200, { 'content-type' => 'application/json' }, [updated_category.to_json]]
    else
      not_found
    end
  end

  def delete_category(req)
    id = req.path_info.split('/').last.to_i
    if @categories.where(id: id).delete > 0
      [200, { 'content-type' => 'text/plain' }, ["Category with id #{id} deleted"]]
    else
      not_found
    end
  end

  def not_found
    [404, { 'content-type' => 'text/plain' }, ['Not Found']]
  end

  def validate_item(params)
    errors = []
    if params['name'].nil? || params['name'].strip.empty?
      errors << 'Name must be present.'
    end

    if params['price'].nil?
      errors << 'Price must be present.'
    elsif params['price'].to_f <= 0
      errors << 'Price must be a greater than 0.'
    end

    if params['category_id'].nil?
      errors << 'Category ID must be present.'
    elsif @categories.where(id: params['category_id']).count.zero?
      errors << 'Category ID must reference an existing category.'
    end

    errors
  end

  def unauthorized
    [
      401,
      {
        'content-type' => 'application/json',
        'www-authenticate' => 'Basic realm="Restricted Area"'
      },
      [{ error: 'Unauthorized' }.to_json]
    ]
  end
  
  def not_found
    [404, { 'content-type' => 'application/json' }, [{ error: 'Not found' }.to_json]]
  end

  def authenticated?(req)
    auth_header   = req.env['HTTP_AUTHORIZATION']
    return false unless auth_header&.start_with?('Basic ')

    encoded_credentials = auth_header.split(' ', 2).last
    decoded_credentials = Base64.decode64(encoded_credentials)
    username, password = decoded_credentials.split(':', 2)
    valid_credentials?(username, password)
  end

  def valid_credentials?(username, password)
    username == ENV['HTTP_AUTH_USERNAME'] && password == ENV['HTTP_AUTH_PASSWORD'] 
  end
end
