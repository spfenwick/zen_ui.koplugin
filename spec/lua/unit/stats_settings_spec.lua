describe("stats settings", function()
    local saved_settings
    local saved_default_font_size
    local saved_font_size
    local arrange_options
    local shown_widget

    before_each(function()
        local settings = {
            widgets = {
                order = { "today", "this_week", "trend_graph" },
                enabled = { today = false, this_week = false },
                options = {
                    this_week = { id = "this_week", font_size = 15 },
                    trend_graph = { id = "trend_graph", metric = "pages", range_days = 14 },
                },
            },
        }
        local StatsSettings = {
            MAX_WIDGET_SLOTS = 6,
            load = function() return settings end,
            save = function(current)
                local widgets = current.widgets
                local order, enabled = {}, {}
                for _i, id in ipairs(widgets.order) do order[_i] = id end
                for id, value in pairs(widgets.enabled) do enabled[id] = value end
                local graph = widgets.options.trend_graph
                local this_week = widgets.options.this_week
                current.widgets = {
                    order = order,
                    enabled = enabled,
                    options = {
                        this_week = {
                            id = this_week.id,
                            font_size = this_week.font_size,
                        },
                        trend_graph = {
                            id = graph.id,
                            metric = graph.metric,
                            range_days = graph.range_days,
                        },
                    },
                }
                saved_settings = current.widgets
                saved_default_font_size = current.font_size
                saved_font_size = current.widgets.options.this_week.font_size
            end,
            widgetSlots = function() return 1 end,
            hasFontSize = function(id) return id == "this_week" end,
        }

        ZenSpec.replace("gettext", function(text) return text end)
        ZenSpec.replace("ui/uimanager", {
            scheduleIn = function() end,
            show = function(_self, widget) shown_widget = widget end,
        })
        ZenSpec.replace("ui/widget/spinwidget", { new = function(_self, opts) return opts end })
        ZenSpec.replace("modules/filebrowser/patches/stats_settings", StatsSettings)
        ZenSpec.replace("config/preset_store", {})
        ZenSpec.replace("modules/filebrowser/patches/home/home_presets", {})
        ZenSpec.replace("common/reading_goals", {})
        ZenSpec.replace("common/shared_state", { get = function() end })
        ZenSpec.replace("common/inline_icon_map", { settings_stats = "stats" })
        ZenSpec.replace("common/ui/icon_menu_item", { decorate = function(item) return item end })
        ZenSpec.replace("common/ui/zen_arrange_list", {
            show = function(opts) arrange_options = opts end,
        })
        ZenSpec.unload("modules/settings/sections/stats_settings")
    end)

    it("persists each widget change while the menu remains open", function()
        local section = require("modules/settings/sections/stats_settings").build({})
        section.sub_item_table[1].callback()
        arrange_options.item_table[1].callback()
        arrange_options.item_table[2].callback()

        assert.is_true(saved_settings.enabled.today)
        assert.is_true(saved_settings.enabled.this_week)
    end)

    it("persists consecutive graph settings", function()
        local section = require("modules/settings/sections/stats_settings").build({})
        section.sub_item_table[1].callback()
        local graph_items = arrange_options.item_table[3].sub_item_table_func()
        graph_items[1].sub_item_table[2].callback()
        graph_items[2].sub_item_table_func()[3].callback()

        assert.are.equal("time", saved_settings.options.trend_graph.metric)
        assert.are.equal(30, saved_settings.options.trend_graph.range_days)
    end)

    it("persists a widget font size", function()
        local section = require("modules/settings/sections/stats_settings").build({})
        section.sub_item_table[1].callback()
        local font_items = arrange_options.item_table[2].sub_item_table_func()
        font_items[1].callback()
        shown_widget.callback({ value = 17 })

        assert.are.equal(17, saved_font_size)
    end)

    it("persists the default font size", function()
        local section = require("modules/settings/sections/stats_settings").build({})
        section.sub_item_table[2].callback()
        shown_widget.callback({ value = 19 })

        assert.are.equal(19, saved_default_font_size)
    end)
end)
