module JsonObjectValidatable
  extend ActiveSupport::Concern

  class_methods do
    def validates_json_object(*field_names)
      field_names.each do |field_name|
        validate do
          value = public_send(field_name)

          next if value.is_a?(Hash)

          errors.add(field_name, "must be a JSON object")
        end
      end
    end
  end
end
