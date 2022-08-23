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
use vunit_lib.print_pkg.all;

entity tb_id is
  generic(
    runner_cfg : string
  );
end entity;

architecture tb of tb_id is
begin
  main : process
    variable id, grandparent, parent, child, second_child, grandchild : id_t;
    constant id_tree : string := get_tree;
    variable n_children : natural := 0;
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
        grandchild := get_id("second_child:grandchild", parent);
        second_child := get_id("parent:second_child");
        check_equal(name(parent), "parent");
        check_equal(name(child), "child");
        check_equal(name(second_child), "second_child");
        check_equal(name(grandchild), "grandchild");
        check_equal(full_name(parent), "parent");
        check_equal(full_name(child), "parent:child");
        check_equal(full_name(second_child), "parent:second_child");
        check_equal(full_name(grandchild), "parent:second_child:grandchild");
        check(get_parent(parent) = root_id);
        check(get_parent(child) = parent);
        check(get_parent(second_child) = parent);
        check(get_parent(grandchild) = second_child);
        check(get_parent(second_child) = parent);
        check_equal(num_children(parent), 2);
        check_equal(num_children(second_child), 1);
        check_equal(num_children(child), 0);
        check_equal(num_children(grandchild), 0);
        check(get_child(parent, 0) = child);
        check(get_child(parent, 1) = second_child);
        check(get_child(second_child, 0) = grandchild);

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
        check(to_id(to_integer(null_id)) = null_id);
        check(to_id(to_integer(root_id)) = root_id);

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

      elsif run("Test pretty-printing ID tree") then
        check_equal(id_tree(id_tree'left to id_tree'left + 6), LF & "(root)");

        grandparent := get_id("grandparent");
        check_equal(get_tree(grandparent), LF & "grandparent");
        check_equal(get_tree(grandparent, initial_lf => false), "grandparent");

        id := get_id("grandparent:1st parent");
        check_equal(get_tree(grandparent),
                    LF & "grandparent" & LF & "\---1st parent");

        id := get_id("grandparent:2nd parent");
        check_equal(get_tree(grandparent),
                    LF & "grandparent" & LF & "+---1st parent" & LF & "\---2nd parent");

        id := get_id("grandparent:1st parent:1st child");
        check_equal(get_tree(grandparent),
                    LF & "grandparent" & LF & "+---1st parent" & LF & "|   \---1st child" & LF & "\---2nd parent");

        id := get_id("grandparent:1st parent:2nd child");
        check_equal(get_tree(grandparent),
                    LF & "grandparent" & LF & "+---1st parent" & LF & "|   +---1st child" & LF & "|   \---2nd child" & LF & "\---2nd parent");

        id := get_id("grandparent:1st parent:3rd child");
        check_equal(get_tree(grandparent),
                    LF & "grandparent" & LF & "+---1st parent" & LF & "|   +---1st child" & LF & "|   +---2nd child" & LF & "|   \---3rd child" & LF & "\---2nd parent");

        id := get_id("grandparent:2nd parent:4th child");
        check_equal(get_tree(grandparent),
                    LF & "grandparent" & LF & "+---1st parent" & LF & "|   +---1st child" & LF & "|   +---2nd child" & LF & "|   \---3rd child" & LF & "\---2nd parent" & LF & "    \---4th child");

        id := get_id("grandparent:1st parent:1st child:1st grandchild");
        check_equal(get_tree(grandparent),
                    LF & "grandparent" & LF & "+---1st parent" & LF & "|   +---1st child" & LF & "|   |   \---1st grandchild" & LF & "|   +---2nd child" & LF & "|   \---3rd child" & LF & "\---2nd parent" & LF & "    \---4th child");

        print("Full ID tree:" & get_tree);

      elsif run("Test that created identities exist") then
        check_true(exists(""));
        id := get_id("parent:child:grandchild");
        check_true(exists("parent"));
        check_true(exists("parent:child"));
        check_true(exists("parent:child:grandchild"));
        id := get_id("parent");
        id := get_id("parent:child");
        id := get_id("parent:child:grandchild");
        check_true(exists("child", get_id("parent")));
        check_true(exists("child:grandchild", get_id("parent")));
        check_true(exists("grandchild", get_id("parent:child")));

      elsif run("Test that non-existing identities do not exist") then
        check_false(exists("parent"));
        id := get_id("parent:child");
        check_false(exists("child"));

      elsif run("Test root_id") then
        check(get_parent(root_id) = null_id);
        n_children := num_children(root_id);
        id := get_id("id");
        check_equal(num_children(root_id), n_children + 1);
        check(get_child(root_id, n_children) = id);
        check_equal(full_name(root_id), "");
        check_equal(name(root_id), "");

      elsif run("Test get_parent(null_id)") then
        mock_core_failure;
        id := get_parent(null_id);
        check_core_failure("get_parent is not defined for null_id.");
        unmock_core_failure;

      elsif run("Test num_children(null_id)") then
        mock_core_failure;
        n_children := num_children(null_id);
        check_core_failure("num_children is not defined for null_id.");
        unmock_core_failure;

      elsif run("Test get_child(null_id)") then
        mock_core_failure;
        id := get_child(null_id, 0);
        check_core_failure("get_child is not defined for null_id.");
        unmock_core_failure;

      elsif run("Test full_name(null_id)") then
        mock_core_failure;
        info(full_name(null_id));
        check_core_failure("full_name is not defined for null_id.");
        unmock_core_failure;

      elsif run("Test name(null_id)") then
        mock_core_failure;
        info(name(null_id));
        check_core_failure("name is not defined for null_id.");
        unmock_core_failure;

      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;
end architecture;
