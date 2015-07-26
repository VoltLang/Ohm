module ohm.settings;


import std.algorithm : startsWith;
import std.path : stdExpandTilde = expandTilde, isDirSeparator, buildNormalizedPath, dirName, dirSeparator;
import std.process : environment;

import volt.interfaces : VoltSettings = Settings;


class Settings : VoltSettings
{
public:
	/// Path to the ohm history file.
	string historyFile = buildNormalizedPath("~", ".ohm_history");

	/// Don't print the value of an assign expression.
	bool ignoreAssignExpValue = false;

	/// Show stacktraces instead of small error messages. Only useful for debugging Ohm.
	bool showStackTraces = false;

	this(string execDir)
	{
		super(execDir);
	}
}


string expandTilde(string path)
{
	version (Windows) {
		// this is based on the Python implementation of os.ntpath.expandUser

		if (!startsWith(path, "~")) {
			return path;
		}

		string name;
		string restOfPath;
		foreach (size_t i, c; path) {
			if (isDirSeparator(c)) {
				name = path[1..i];
				restOfPath = path[i..$];
				break;
			}
		}

		enum envVars = ["HOME", "USERPROFILE"];

		string userHome = null;
		foreach (envvar; envVars) {
			auto val = environment.get(envvar);
			if (val !is null) {
				userHome = val;
				break;
			}
		}

		if (userHome is null && !environment.get("HOMEPATH")) {
			return path;
		} else {
			string drive = environment.get("HOMEPATH", "");
			userHome = buildNormalizedPath(drive, environment["HOMEPATH"]);
		}

		return buildNormalizedPath(userHome, "." ~ dirSeparator ~ restOfPath);
	} else {
		return stdExpandTilde(path);
	}
}