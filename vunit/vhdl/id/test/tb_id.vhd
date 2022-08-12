-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2022, Lars Asplund lars.anders.asplund@gmail.com

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.id_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.core_pkg.all;

entity tb_id is
  generic(
    runner_cfg : string
  );
end entity;

architecture tb of tb_id is
begin
  main : process
    variable id, grandparent, parent, child, second_child : id_t;
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      if run("Test creating new ID without parent") then
        info(main'path_name);
        id := get_id("id");
        check_equal(name(id), "id");
        check_equal(full_name(id), "id");
        check(get_parent(id) = root_id);
        check_equal(num_children(id), 0);

      elsif run("Test creating new ID with parent") then
        parent := get_id("parent");
        child := get_id("child", parent);
        check_equal(name(parent), "parent");
        check_equal(name(child), "child");
        check_equal(full_name(parent), "parent");
        check_equal(full_name(child), "parent:child");
        check(get_parent(parent) = root_id);
        check(get_parent(child) = parent);
        check_equal(num_children(parent), 1);
        check_equal(num_children(child), 0);
        check(get_child(parent, 0) = child);

      elsif run("Test creating new ID with parent from manual path") then
        parent := get_id("parent");
        child := get_id("parent:child");
        check_equal(name(parent), "parent");
        check_equal(name(child), "child");
        check_equal(full_name(parent), "parent");
        check_equal(full_name(child), "parent:child");
        check(get_parent(parent) = root_id);
        check(get_parent(child) = parent);
        check_equal(num_children(parent), 1);
        check_equal(num_children(child), 0);
        check(get_child(parent, 0) = child);

      elsif run("Test creating hierarchy of IDs from manual path") then
        child := get_id("parent:child");
        parent := get_parent(child);
        check_equal(name(parent), "parent");
        check_equal(name(child), "child");
        check_equal(full_name(parent), "parent");
        check_equal(full_name(child), "parent:child");
        check(get_parent(parent) = root_id);
        check(get_parent(child) = parent);
        check_equal(num_children(parent), 1);
        check_equal(num_children(child), 0);
        check(get_child(parent, 0) = child);

      elsif run("Test creating hierarchy from path_name attribute") then
        child := get_id(child'path_name);
        parent := get_parent(child);
        grandparent := get_parent(parent);
        check_equal(name(child), "child");
        check_equal(name(parent), "main");
        check_equal(name(grandparent), "tb_id");
        check_equal(full_name(child), "tb_id:main:child");
        check_equal(full_name(parent), "tb_id:main");
        check_equal(full_name(grandparent), "tb_id");
        check(get_parent(child) = parent);
        check(get_parent(parent) = grandparent);
        check(get_parent(grandparent) = root_id);
        check_equal(num_children(child), 0);
        check_equal(num_children(parent), 1);
        check_equal(num_children(grandparent), 1);
        check(get_child(parent, 0) = child);
        check(get_child(grandparent, 0) = parent);

      elsif run("Test creating hierarchy from instance_name attribute") then
        child := get_id(child'instance_name);
        parent := get_parent(child);
        grandparent := get_parent(parent);
        check_equal(name(child), "child");
        check_equal(name(parent), "main");
        check_equal(name(grandparent), "tb_id(tb)");
        check_equal(name(grandparent), "tb_id(tb)");
        check_equal(full_name(child), "tb_id(tb):main:child");
        check_equal(full_name(parent), "tb_id(tb):main");
        check(get_parent(child) = parent);
        check(get_parent(parent) = grandparent);
        check(get_parent(grandparent) = root_id);
        check_equal(num_children(child), 0);
        check_equal(num_children(parent), 1);
        check_equal(num_children(grandparent), 1);
        check(get_child(parent, 0) = child);
        check(get_child(grandparent, 0) = parent);

      elsif run("Test ID name validation") then
        id := get_id("parent:child");
        check(id /= null_id);

        mock_core_failure;
        id := get_id("parent,child");
        check_core_failure("Invalid ID name ""parent,child""");

        id := get_id("grandparent:parent,child");
        check_core_failure("Invalid ID name ""grandparent:parent,child""");

        id := get_id("");
        check_core_failure("Invalid ID name """"");
        check(id = null_id);

        id := get_id(":");
        check_core_failure("Invalid ID name """"");
        check(id = null_id);

        unmock_core_failure;

      elsif run("Test getting existing ID") then
        child := get_id(child'instance_name);
        parent := get_parent(child);
        grandparent := get_parent(parent);
        check(get_id(child'instance_name) = child);
        check(get_id("tb_id(tb):main:child") = child);
        check(get_id(main'instance_name) = parent);
        check(get_id("tb_id(tb):main") = parent);
        check(get_id(tb_id'instance_name) = grandparent);
        check(get_id("tb_id(tb)") = grandparent);

      elsif run("Test multiple children to a parent") then
        parent := get_id("parent");
        check_equal(num_children(parent), 0);

        child := get_id("child", parent);
        check_equal(num_children(parent), 1);
        check(get_child(parent, 0) = child);
        second_child := get_id("second child", parent);
        check_equal(num_children(parent), 2);
        check(get_child(parent, 0) = child);
        check(get_child(parent, 1) = second_child);

      elsif run("Test ID to/from integer conversion") then
        id := get_id("id");
        check(to_id(to_integer(id)) = id);

      elsif run("Test same name IDs at different hierarchy positions") then
        child := get_id("grandparent:parent:child");
        second_child := get_id("grandparent:child");
        check_equal(name(child), "child");
        check_equal(name(second_child), "child");
        check_equal(full_name(child), "grandparent:parent:child");
        check_equal(full_name(second_child), "grandparent:child");
        check_equal(num_children(get_id("grandparent")), 2);
        check_equal(num_children(get_id("grandparent:parent")), 1);
        check(get_id("grandparent:parent:child") = child);
        check(get_id("grandparent:child") = second_child);
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
