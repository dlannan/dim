| Module / Object       | Function / Method         | Description                                           |
| --------------------- | ------------------------- | ----------------------------------------------------- |
| `core`                | `open_doc(filename)`      | Opens a document or retrieves it if already loaded    |
| `core`                | `get_doc(filename)`       | Returns the document if open, else nil                |
| `core`                | `add_thread(fn, weakref)` | Starts a coroutine thread for background work         |
| `core`                | `reload_module(name)`     | Reloads a Lua module dynamically                      |
| `core`                | `close_doc(doc)`          | Closes a document, cleaning resources                 |
| `core.docs`           | (table)                   | Table containing all open documents                   |
| `Doc`                 | `save()`                  | Saves the document to disk                            |
| `Doc`                 | `insert(text, pos)`       | Inserts text at a position                            |
| `Doc`                 | `remove(start, end)`      | Removes text between positions                        |
| `Doc`                 | `get_text(start, end)`    | Gets text between positions                           |
| `Doc`                 | `set_syntax(syntax)`      | Sets syntax highlighter for the doc                   |
| `Doc`                 | `get_line(line_number)`   | Returns text of a specific line                       |
| `View`                | `draw()`                  | Draws the view/editor window                          |
| `View`                | `set_doc(doc)`            | Sets the document for the view                        |
| `View`                | `scroll_to(pos)`          | Scrolls the view to a given position                  |
| `View`                | `get_cursor_pos()`        | Returns cursor position                               |
| `View`                | `set_cursor_pos(pos)`     | Sets cursor position                                  |
| `View`                | `on_mouse_event(event)`   | Handles mouse input events                            |
| `View`                | `on_key_event(event)`     | Handles keyboard input events                         |
| `Node`                | `split(direction, doc)`   | Splits the node horizontally or vertically with a doc |
| `Node`                | `close()`                 | Closes the node/view                                  |
| `root_view`           | `get_active_node()`       | Returns the currently focused node                    |
| `command`             | `add(bindings)`           | Adds keyboard command bindings                        |
| `command`             | `run(name)`               | Runs a command by name                                |
| `syntax`              | `add(definition)`         | Adds syntax definition (keywords, patterns, etc.)    |
| `syntax`              | `match(doc, pos)`         | Returns syntax highlight info at a position           |
| `keymap`              | `add(bindings)`           | Adds keyboard shortcuts                               |
| `keymap`              | `get_binding(key)`        | Returns command bound to a key                        |
| `style`               | (table)                   | Holds style info for colors, fonts, padding           |
| `style.load()`       |                            | Loads styles/themes                                   |
| `core.file_watch`     | `add(path, callback)`     | Watches a file or directory for changes               |
| `core.file_watch`     | `remove(path)`            | Stops watching a file or directory                    |
| `core.plugin_manager` | `load_plugin(path)`       | Loads a plugin Lua module                             |
| `core.plugin_manager` | `unload_plugin(name)`     | Unloads a plugin                                      |
| `core.plugin_manager` | `reload_plugin(name)`     | Reloads a plugin                                      |
| `core.event`          | `add_listener(name, fn)`  | Adds event listener                                   |
| `core.event`          | `emit(name, args...)`     | Emits an event                                        |
