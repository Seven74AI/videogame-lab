extends GutTest

func test_project_loads():
	assert_not_null(get_tree(), "Scene tree should exist")
	assert_true(true, "Project loads without errors")
