# Include hook code here

if Rails.env == 'test'
  ClayBlueprint.find_clay_blueprints(Rails.root)
end

