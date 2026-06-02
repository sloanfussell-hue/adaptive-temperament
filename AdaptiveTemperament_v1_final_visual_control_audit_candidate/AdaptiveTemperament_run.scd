(
var runPath, baseDir, manifestPath;

runPath = thisProcess.nowExecutingPath;
runPath.isNil.if({
    Error("[AT run] Save this file to disk before evaluating it.").throw;
});

baseDir = PathName(runPath).pathOnly;
manifestPath = baseDir +/+ "src/00_boot/AT_manifest.scd";

manifestPath.pathMatch.isEmpty.if({
    Error("[AT run] Missing manifest: " ++ manifestPath).throw;
});

manifestPath.load;

Server.default.waitForBoot({
    (~atBoot.isNil).if({
        Error("[AT run] Manifest did not define ~atBoot.").throw;
    });
    ~atBoot.value(baseDir, true, false);
});
)
