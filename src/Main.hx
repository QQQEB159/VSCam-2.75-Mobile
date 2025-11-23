package;

import flixel.FlxGame;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxTweenManager;
import funkin.backend.LanguageHandler;
import funkin.backend.FPSCounter;
import funkin.backend.AwardCard;
import haxe.CallStack;
import haxe.io.Path;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.UncaughtErrorEvent;
#if mobile
import mobile.backend.StorageUtil;
#end

#if (linux && !debug)
@:cppInclude('../../../../src/_external/gamemode_client.h') // i don't care enough to properly point back to the src folder whatever it works fuck you
@:cppFileCode('#define GAMEMODE_AUTO')
#end
class Main extends Sprite {
	public static var fpsCounter:FPSCounter;
	public static var awardsCard:AwardCard;
	public static var keyboardInputs:Bool = true;
	public static var isClosing:Bool = false;
	public static var windowTween:FlxTween = null;
	/**
	 * Tween Manager that works regardless FlxG.timeScale
	 */
	public static var tweenManager:FlxTweenManager = null;

	public function new() {
		super();

		#if mobile
		#if android
		StorageUtil.requestPermissions();
		#end
		Sys.setCwd(StorageUtil.getStorageDirectory());
		#end
		mobile.backend.CrashHandler.init();
		
		//Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);

		addChild(new FlxGame(InitState, 1280, 720, 60, true));
		addChild(fpsCounter = new FPSCounter(10, 10, 12));
		fpsCounter.visible = Settings.data.fpsCounter;
		addChild(awardsCard = new AwardCard());

		@:privateAccess FlxG.keys._nativeCorrection.set("0_43", FlxKey.PLUS);
		
		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end
	}

	override function __enterFrame(delta:Int) {
		super.__enterFrame(delta);

		if (isClosing) return;

		@:privateAccess
		FlxG.mouse.enabled = !FlxG.game._lostFocus;
	}

	public static function clearExceptWindow() {
		@:privateAccess if (FlxTween.globalManager == null || FlxTween.globalManager._tweens == null) return;

		@:privateAccess final twns = FlxTween.globalManager._tweens;

		for (tween in twns){
			if (tween == null || tween == windowTween) continue;

			tween.active = false;
			tween.destroy();
		}

		twns.splice(0, twns.length);

		if (windowTween != null)
			twns.push(windowTween);
	}

	#if windows
	// Get rid of hit test function because mouse memory ramp up during first move (-Bolo)
	@:noCompletion override function __hitTest(_, _, _, _, _, _):Bool return false;
	@:noCompletion override function __hitTestHitArea(_, _, _, _, _, _):Bool return false;
	@:noCompletion override function __hitTestMask(_, _):Bool return false;
	#end

	function onCrash(e:UncaughtErrorEvent):Void {
		e.preventDefault();
		e.stopImmediatePropagation();

		var errMsg:String = '${e.error}\n\n';
		var date:String = '${Date.now()}'.replace(":", "'");

		for (stackItem in CallStack.exceptionStack(true)) {
			switch (stackItem) {
				case FilePos(_, file, line, _): errMsg += 'Called from $file:$line\n';
				default: Sys.println(stackItem);
			}
		}

		errMsg += '\nExtra Info:\n';
		errMsg += 'Operating System: ${Util.getOperatingSystem()}\nTarget: ${Util.getTarget()}\n\n';

		final defines:Map<String, Dynamic> = _external.CompilerDefines.list;
		errMsg += 'Haxe: ${defines['haxe']}\nFlixel: ${defines['flixel']}\nOpenFL: ${defines['openfl']}\nLime: ${defines['lime']}';

		if (!FileSystem.exists('crash/')) FileSystem.createDirectory('crash/');

		File.saveContent('crash/$date.txt', '$errMsg\n');
		Sys.println('\n$errMsg');
		lime.app.Application.current.window.alert(errMsg, "Error!");
		Sys.exit(1);
	}
}

class InitState extends flixel.FlxState {
	override function create():Void {
		setDefines();
		if(!CopyState.checkExistingFiles())
		flixel.FlxG.switchState(new CopyState());
		else
		flixel.FlxG.switchState(new TitleState());
	}

	private function setDefines() {
		try {
			Main.tweenManager = new FlxTweenManager();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to create FlxTweenManager: ${e.message}');
			throw e;
		}

		try {
			Controls.load();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to load Controls: ${e.message}');
			throw e;
		}

		try {
			Settings.load();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to load Settings: ${e.message}');
			throw e;
		}

		try {
			Scores.load();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to load Scores: ${e.message}');
			throw e;
		}

		#if DISCORD_ALLOWED
		try {
			DiscordClient.start();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to start Discord RPC: ${e.message}');
			// Don't throw - Discord is not critical
		}
		#end

		try {
			Addons.load();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to load Addons: ${e.message}');
			throw e;
		}

		try {
			Awards.load();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to load Awards: ${e.message}');
			throw e;
		}

		try {
			Meta.cacheFiles();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to cache Meta files: ${e.message}');
			// Don't throw - meta caching is not critical if songs don't exist
		}

		try {
			funkin.modchart.ModchartManager.setupRedirects();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup modchart redirects: ${e.message}');
			// Don't throw - modcharts might not be used
		}

		try {
			LanguageHandler.loadTranslations();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to load translations: ${e.message}');
			throw e;
		}

		try {
			Settings.validate();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to validate Settings: ${e.message}');
			throw e;
		}

		try {
			LanguageHandler.setLanguage(Settings.data.language);
		} catch (e:haxe.Exception) {
			Sys.println('Failed to set language: ${e.message}');
			// Don't throw - will use default language
		}

		try {
			var cursorPath = 'assets/images/cursor.png';
			#if mobile
			cursorPath = mobile.backend.StorageUtil.getStorageDirectory(true) + cursorPath;
			#end
			if (FileSystem.exists(cursorPath)) {
				FlxG.mouse.load(openfl.display.BitmapData.fromFile(cursorPath));
			} else {
				Sys.println('Cursor file not found: ${cursorPath}');
			}
		} catch (e:haxe.Exception) {
			Sys.println('Failed to load cursor: ${e.message}');
			// Don't throw - cursor is not critical
		}

		try {
			FlxG.fullscreen = #if mobile true #else Settings.data.fullscreen #end;
			FlxG.fixedTimestep = false;
			FlxG.drawFramerate = FlxG.updateFramerate = Settings.data.framerate;
			FlxG.game.focusLostFramerate = Math.floor(Settings.data.framerate / 4);
			FlxG.keys.preventDefaultKeys = [TAB];
			FlxG.cameras.useBufferLocking = true;
			FlxG.autoPause = Settings.data.autoPause;
		} catch (e:haxe.Exception) {
			Sys.println('Failed to set FlxG settings: ${e.message}');
			throw e;
		}

		try {
			FlxAudioHandler.init();
		} catch (e:haxe.Exception) {
			Sys.println('Failed to initialize FlxAudioHandler: ${e.message}');
			throw e;
		}

		try {
			FlxG.signals.focusGained.add(()->{
				FlxAudioHandler.onFocus();
			});

			FlxG.signals.focusLost.add(()->{
				if (!FlxG.autoPause)
					return;
				FlxAudioHandler.onFocusLost();
			});
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup focus handlers: ${e.message}');
			throw e;
		}

		try {
			FlxG.sound.volumeHandler = (v:Float) -> {
				FlxG.save.data.volume = v;
				FlxAudioHandler.volume = v;

				@:privateAccess
				FlxAudioHandler.music._audioBackend.updateVolume();

				for (al in FlxAudioHandler.audioList) {
					if (!al.exists) continue;
					@:privateAccess
					al._audioBackend.updateVolume();
				}
			}
			FlxG.sound.volumeUpKeys = Controls.binds["volume_up"];
			FlxG.sound.volumeDownKeys = Controls.binds["volume_down"];
			FlxG.sound.muteKeys = Controls.binds["volume_mute"];
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup volume handlers: ${e.message}');
			throw e;
		}

		try {
			FlxG.signals.preUpdate.add(()->{
				Main.tweenManager.update(FlxG.elapsed/FlxG.timeScale);
			});
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup preUpdate signal: ${e.message}');
			throw e;
		}

		try {
			FlxG.signals.preStateSwitch.add(()->{
				Conductor.reset();
				FlxAudioHandler.checkStoredSounds();
			});
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup preStateSwitch signal: ${e.message}');
			throw e;
		}

		/*FlxG.stage.application.onExit.add(function(exitCode:Int)
		{
			FlxG.save.close();
		});*/ //yeah uhh... that should be with the code of the window close event

		try {
			FlxG.sound.volume = FlxG.save.data.volume ?? 1.0;
			FlxG.sound.muted = FlxG.save.data.muted ?? false;
			FlxG.sound.volumeHandler(FlxG.sound.muted ? 0 : FlxG.sound.volume);
			#if desktop
			FlxG.game.soundTray.updateWithSettings();
			#end
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup sound settings: ${e.message}');
			throw e;
		}

		try {
			openfl.Lib.application.window.onClose.add(function () {
				Main.isClosing = true;
				Main.keyboardInputs = false;
				FlxG.mouse.enabled = false;

				FlxG.save.data.volume = FlxG.sound.volume;
				FlxG.save.data.muted = FlxG.sound.muted;
				FlxG.save.flush();
				FlxG.save.close();

				if (FlxG.state is funkin.states.OptionsState) {
					Controls.save();
					Settings.save();
				}

				if(Settings.data.closeAnimation){
					openfl.Lib.application.window.onClose.cancel();
					FlxG.autoPause = false;
					//i'm killimg my ahh!!!! -blear
					// me too - rudy
					// why is this CAUSING MY GAME TO STOP RESPONDING!!! -neb
					// i don't have anything to add to this i just wanna participate -fox
					// ooh! me next! me next! i wanna add a comment too! -srt
					// hi guys i'm also here -tictacto
					// she strogan on my beef til i'm off -lno
					
					Conductor.stop();
					FlxG.sound.play(Paths.audio("byebye", 'sfx'));
					Main.windowTween = FlxTween.num(255, 0, 2, {ease: FlxEase.quadInOut, 
						onUpdate: tween -> {
							var curVal = Std.int(255 + (0 - 255) * tween.scale);
							funkin.backend.WindowUtils.setWindowOpacity(Std.int(curVal));}, 
						onComplete: tween -> Sys.exit(1)});
				}
			}, true);
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup window close handler: ${e.message}');
			// Don't throw - window close handler is not critical for startup
		}

		try {
			FlxG.signals.preStateSwitch.remove(FlxTween.globalManager.clear);
			FlxG.signals.preStateSwitch.add(Main.clearExceptWindow);
		} catch (e:haxe.Exception) {
			Sys.println('Failed to setup state switch cleanup: ${e.message}');
			throw e;
		}

		try {
			FlxG.plugins.add(new funkin.backend.Conductor());
		} catch (e:haxe.Exception) {
			Sys.println('Failed to add Conductor plugin: ${e.message}');
			throw e;
		}
	}
}
