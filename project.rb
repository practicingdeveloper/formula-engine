require 'dentaku'
require 'csv'
require 'json'

class Project
  def self.available_projects
    Dir['db/projects/*.csv'].map { |filename|
      filename.scan(%r{db\/projects\/(.*)\.csv})
    }.flatten
  end

  def initialize(name, options={})
    @name       = name
    @variables  = JSON.parse(IO.read("db/metadata.json"))[name]["params"]
    @options    = Hash[options.map { |k,v| [k,Dentaku(v)] }]
    @template   = csv_data("db/projects/#{ name }.csv")
  end

  attr_reader :variables

  def helper_formulas
    {
      'box_volume'       => 'rect_area * height',
      'rect_area'        => 'length * width',
      'rect_perimeter'   => '2 * length + 2 * width',
      'cylinder_volume'  => 'circular_area * height',
      'circumference'    => 'pi * diameter',
      'circular_area'    => 'pi * radius^2',
      'radius'           => 'diameter / 2.0',
      'pi'               => '3.1416',
      'fill'             => '0.7'
    }
  end

  def materials
    calculator = Dentaku::Calculator.new
  
    helper_formulas.each { |k,v| calculator.store_formula(k,v) }
    
    @template.each_with_object([]) do |material, list|
      amt = calculator.evaluate(material['formula'], @options)

      list << material.to_hash.merge('quantity' => amt)
    end
  end

  def shipping_weight
    calculator = Dentaku::Calculator.new

    # Build up a hash of weight formulas, keyed by material name
    weight_formulas = csv_data('db/materials.csv').each_with_object({}) do |e, h|
      h[e['name']] = e['weight']
    end

    # Sum up weights for all materials in project based on quantity
    materials.reduce(0.0) { |s, e|
      s + calculator.evaluate(weight_formulas[e['name']], e)
    }.ceil
  end

  private

  def csv_data(path)
    CSV.read(path, :headers => :true)
  end
end
