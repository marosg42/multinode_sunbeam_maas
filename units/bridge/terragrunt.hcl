include "stack" {
  path = find_in_parent_folders("stack.hcl")
  expose = true
}

terraform {
  source = "./"
}

inputs = merge(
  include.stack.locals.stack_config,
  {}
)
