extends GutTest

func test_every_node_type_has_a_loadable_icon():
	for node_type in MapNode.NodeType.values():
		assert_not_null(UiIcons.for_node_type(node_type), "NodeType %d" % node_type)

func test_named_icons_load():
	for name in [&"heart", &"shield", &"bolt", &"flask", &"tree", &"bag", &"gem", &"cards", &"fang"]:
		assert_not_null(UiIcons.texture(name), String(name))

func test_unknown_icon_returns_null():
	assert_null(UiIcons.texture(&"no_such_icon"))
