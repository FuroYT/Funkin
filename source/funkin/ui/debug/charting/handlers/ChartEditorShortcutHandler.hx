package funkin.ui.debug.charting.handlers;

import flixel.input.keyboard.FlxKey;
import funkin.input.TurboKeyHandler;
import funkin.util.PlatformUtil;
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.events.MouseEvent;

typedef ShortcutMap = Map<MenuItem, Void->Bool>;

/**
 * Handles modifying the shortcut text and running the callbacks of menu items based on the current platform.
 * On macOS, `Ctrl`, `Alt`, and `Shift` are replaced with `⌘`, `⌥`, and `⇧` respectively.
 */
@:access(funkin.ui.debug.charting.ChartEditorState)
class ChartEditorShortcutHandler
{
  public static function applyShortcutList(state:ChartEditorState):ShortcutMap
  {
    // Initialize map
    var shortcutList:ShortcutMap = new ShortcutMap();

    // Special Requirements Functions
    var Special_noHaxeFocusOrMouse = () -> !(state.isHaxeUIFocused || state.isCursorOverHaxeUI);
    var Special_noHaxeFocus = () -> !state.isHaxeUIFocused;
    var Special_dontRun = () -> false;
    var Special_isNoLiveInput = () -> state.currentLiveInputStyle == None;

    // File menu
    addShortcut(shortcutList, state.menubarItemNewChart, [CONTROL, N]);
    addShortcut(shortcutList, state.menubarItemOpenChart, [CONTROL, O]);
    addShortcut(shortcutList, state.menubarItemSaveChartAs, [CONTROL, SHIFT, S]);
    addShortcut(shortcutList, state.menubarItemExit, [CONTROL, Q]);

    // Edit menu
    addShortcut(shortcutList, state.menubarItemUndo, [CONTROL, Z], Special_noHaxeFocusOrMouse);
    addShortcut(shortcutList, state.menubarItemRedo, [CONTROL, Y], Special_noHaxeFocusOrMouse);
    addShortcut(shortcutList, state.menubarItemCut, [CONTROL, X], Special_noHaxeFocusOrMouse);
    addShortcut(shortcutList, state.menubarItemCopy, [CONTROL, C], Special_dontRun);
    addShortcut(shortcutList, state.menubarItemPaste, [CONTROL, V], Special_noHaxeFocusOrMouse);
    addShortcut(shortcutList, state.menubarItemPasteUnsnapped, [CONTROL, SHIFT, V], Special_noHaxeFocusOrMouse);
    addShortcut(shortcutList, state.menubarItemFlipNotes, [CONTROL, F], Special_noHaxeFocusOrMouse);

    addShortcut(shortcutList, state.menubarItemDelete, [#if mac BACKSPACE #else DELETE #end], Special_dontRun);

    // Selection
    addShortcut(shortcutList, state.menubarItemSelectAllNotes, [CONTROL, A], Special_dontRun);
    addShortcut(shortcutList, state.menubarItemSelectAllEvents, [CONTROL, ALT, A], Special_dontRun);
    addShortcut(shortcutList, state.menubarItemSelectInverse, [CONTROL, I]);
    addShortcut(shortcutList, state.menubarItemSelectNone, [CONTROL, D]);
    addShortcut(shortcutList, state.menubarItemSelectBeforeCursor, [SHIFT, HOME]);
    addShortcut(shortcutList, state.menubarItemSelectAfterCursor, [SHIFT, END]);

    // Difficulty
    addShortcut(shortcutList, state.menubarItemDifficultyDown, [CONTROL, LEFT], Special_isNoLiveInput);
    addShortcut(shortcutList, state.menubarItemDifficultyUp, [CONTROL, RIGHT], Special_isNoLiveInput);

    // Playtest
    addShortcut(shortcutList, state.menubarItemPlaytestFull, [ENTER], Special_noHaxeFocus);
    addShortcut(shortcutList, state.menubarItemPlaytestMinimal, [SHIFT, ENTER], Special_noHaxeFocus);

    addShortcut(shortcutList, state.menubarItemUserGuide, [F1]);

    return shortcutList;
  }

  static var mappedKeys:Map<FlxKey, FlxKey> = [
    #if mac
    FlxKey.CONTROL => FlxKey.WINDOWS
    #end // Small helper for MacOS, "WINDOWS" is keycode 15, which maps to "COMMAND" on Mac, which is more often used than "CONTROL"
  ];

  static inline function fixKeyForOS(key:FlxKey):FlxKey
  {
    return mappedKeys[key] ?? key;
  }

  static inline function getKeyListForOS(keyList:Array<FlxKey>):Array<FlxKey>
  {
    for (i => key in keyList)
    {
      keyList[i] = fixKeyForOS(key);
    }
    return keyList;
  }

  /**
   * Adds the shortcut to the list from the specified menuItem and keyList which will add the formated key strokes to the shortcutText field
   * Also adds it to the list of items which will be proccessed for keyboard shortcuts
   * @param shortcutList
   * @param menuItem
   * @param keyList
   * @param extraRequirement
   */
  static inline function addShortcut(shortcutList:ShortcutMap, menuItem:MenuItem, keyList:Array<FlxKey>, ?extraRequirement:Void->Bool = null):ShortcutMap
  {
    if (keyList.length == 0) return shortcutList;

    menuItem.shortcutText = formatKeyList(keyList);

    var controlKey = fixKeyForOS(FlxKey.CONTROL);
    var needsShift = keyList.contains(FlxKey.SHIFT);
    var needsAlt = keyList.contains(FlxKey.ALT);
    var needsControl = keyList.contains(controlKey);
    trace(menuItem.text);
    var checkFunction:Void->Bool = () -> {
      if (needsShift != FlxG.keys.pressed.SHIFT) return false;
      if (needsAlt != FlxG.keys.pressed.ALT) return false;
      if (needsControl != FlxG.keys.checkStatus(controlKey, PRESSED)) return false;
      if (extraRequirement != null) if (!extraRequirement()) return false;
      var pressed = true;
      var justPressed = false;
      for (key in keyList)
      {
        var shouldPress = Std.int(key) > 0;
        if (!shouldPress) key = -key;

        var k = fixKeyForOS(key);
        if (FlxG.keys.checkStatus(k, shouldPress ? JUST_PRESSED : JUST_RELEASED))
        {
          justPressed = true;
        }
        else if (!FlxG.keys.checkStatus(k, shouldPress ? PRESSED : RELEASED))
        {
          pressed = false;
          break;
        }
        return justPressed;
      }
      return false;
    };
    shortcutList.set(menuItem, checkFunction);
    return shortcutList;
  }

  /**
   * Formats the keyList argument as a human readable and friendly string
   * Returns `Ctrl+F` on Windows and `⌘+F` (Command) on macOS. for `[FlxKey.CONTROL, FlxKey.F]`
   * @param keyList The List of FlxKeys to format as a string
   */
  static inline function formatKeyList(keyList:Array<FlxKey>):String
  {
    var parts:Array<String> = [];
    for (key in keyList)
    {
      var formattedKey = switch (key)
      {
        case FlxKey.CONTROL:
          PlatformUtil.isMacOS() ? '⌘' : 'Ctrl';
        case FlxKey.SHIFT:
          PlatformUtil.isMacOS() ? '⇧' : 'Shift';
        case FlxKey.ALT:
          PlatformUtil.isMacOS() ? '⌥' : 'Alt';
        case FlxKey.LEFT:
          "←";
        case FlxKey.DOWN:
          "↓";
        case FlxKey.UP:
          "↑";
        case FlxKey.RIGHT:
          "→";
        case FlxKey.DELETE:
          "Del";
        case FlxKey.BACKSPACE:
          "⌫";
        default:
          FlxKey.toStringMap[key] ?? key.toString();
      };
      parts.push(formattedKey);
    }
    return parts.join("+");
  }

  public static function handleShortcuts(shortcutMap:ShortcutMap):Void
  {
    for (item => checkPress in shortcutMap)
    {
      if (item == null) continue;
      if (checkPress())
      {
        var clickHandler = Reflect.getProperty(item, "onClick");
        if (clickHandler != null)
        {
          trace(item.text);
          clickHandler(new MouseEvent(MouseEvent.CLICK));
        }
        else
        {
          trace("clickHandler doesn't exist skipping...");
        }
      }
    }
  }
}
