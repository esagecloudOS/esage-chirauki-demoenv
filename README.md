demoenv Cookbook
================
This cookbook deploys Abiquo environments for custormer's demo on public cloud providers (tested mostly in Digitalocean).

Requirements
------------

- Chef >= 12.5.1
- CentOS >= 6.5

This cookbook depends on the following cookbooks:

- system
- abiquo
- nfs
- iptables
- chef-client
- ssh_authorized_keys

Recipes
-------

* `recipe[demoenv]` - Installs an Abiquo node of the environment.
* `recipe[kvm]` - Installs an Abiquo KVM node.
* `recipe[monitoring]` - Installs an Abiquo monitoring node for the environment.
* `recipe[monolithic]` - Installs an Abiquo Monolithic node for the environment.


Attributes
----------

<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['demoenv']['environment']</tt></td>
    <td>String</td>
    <td>The name of the environment (usually, custormer's name)</td>
    <td><tt>DEMO</tt></td>
  </tr>
  <tr>
    <td><tt>['demoenv']['datacenter_name']</tt></td>
    <td>String</td>
    <td>The name of the datacenter to be created in Abiquo</td>
    <td><tt>"#{node['demoenv']['environment']} DC"</tt></td>
  </tr>
  <tr>
    <td><tt>['demoenv']['rack_name']</tt></td>
    <td>String</td>
    <td>The name of the rack to be created in Abiquo</td>
    <td><tt>"#{node['demoenv']['environment']} DC"</tt></td>
  </tr>
</table>

Usage
-----

It is advised to create a role for each of the profiles this cookbook can manage. In those
roles, override any attributes from the dependent cookbooks to modify its behaviour.

For example, Abiquo cookbook attributes like ```['abiquo']['profile']``` can be set into the role.

Just include `demoenv` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[demoenv]"
  ]
}
```

This will resolve all the attributes and setup the node accordingly.

Contributing
------------

1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------

* Author:: Marc Cirauqui (marc.cirauqui@abiquo.com)

Copyright:: 2014, Abiquo

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
