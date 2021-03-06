{-# LANGUAGE NamedFieldPuns #-}

-- | cabal-install CLI command: repl
--
module Distribution.Client.CmdRepl (
    replCommand,
    replAction,
  ) where

import Distribution.Client.ProjectOrchestration
         ( PreBuildHooks(..), runProjectPreBuildPhase, selectTargets
         , ProjectBuildContext(..), runProjectBuildPhase
         , printPlan, reportBuildFailures )
import Distribution.Client.ProjectConfig
         ( BuildTimeSettings(..) )
import Distribution.Client.ProjectPlanning
         ( PackageTarget(..) )
import Distribution.Client.BuildTarget
         ( readUserBuildTargets )

import Distribution.Client.Setup
         ( GlobalFlags, ConfigFlags(..), ConfigExFlags, InstallFlags )
import Distribution.Simple.Setup
         ( HaddockFlags, fromFlagOrDefault )
import Distribution.Verbosity
         ( normal )

import Control.Monad (unless)

import Distribution.Simple.Command
         ( CommandUI(..), usageAlternatives )
import Distribution.Simple.Utils
         ( wrapText )
import qualified Distribution.Client.Setup as Client

replCommand :: CommandUI (ConfigFlags, ConfigExFlags, InstallFlags, HaddockFlags)
replCommand = Client.installCommand {
  commandName         = "new-repl",
  commandSynopsis     = "Open a REPL for the current project",
  commandUsage        = usageAlternatives "new-repl" [ "[FLAGS] TARGET" ],
  commandDescription  = Just $ \_ -> wrapText $
        "Opens a REPL for a Nix-local build project.",
  commandNotes        = Just $ \pname ->
        "Examples:\n"
     ++ "  " ++ pname ++ " new-repl cname"
     ++ "    Open a REPL for the component named cname\n"
     ++ "  " ++ pname ++ " new-repl pkgname:cname"
     ++ "    Open a REPL for the component named cname in pkgname\n"
   }

-- | The @repl@ command is very much like @build@. It brings the install plan
-- up to date, selects that part of the plan needed by the given or implicit
-- repl target and then executes the plan.
--
-- Compared to @build@ the difference is that only one target is allowed
-- (given or implicit) and the target type is repl rather than build. The
-- general plan execution infrastructure handles both build and repl targets.
--
-- For more details on how this works, see the module
-- "Distribution.Client.ProjectOrchestration"
--
replAction :: (ConfigFlags, ConfigExFlags, InstallFlags, HaddockFlags)
              -> [String] -> GlobalFlags -> IO ()
replAction (configFlags, configExFlags, installFlags, haddockFlags)
           targetStrings globalFlags = do

    userTargets <- readUserBuildTargets targetStrings

    buildCtx@ProjectBuildContext{buildSettings, elaboratedPlan} <-
      runProjectPreBuildPhase
        verbosity
        ( globalFlags, configFlags, configExFlags
        , installFlags, haddockFlags )
        PreBuildHooks {
          hookPrePlanning      = \_ _ _ -> return (),
          hookSelectPlanSubset = selectReplTargets userTargets
        }

    printPlan verbosity buildCtx

    unless (buildSettingDryRun buildSettings) $ do
      buildResults <- runProjectBuildPhase verbosity buildCtx
      reportBuildFailures verbosity elaboratedPlan buildResults
  where
    verbosity = fromFlagOrDefault normal (configVerbosity configFlags)

    -- When we interpret the targets on the command line, interpret them as
    -- repl targets (as opposed to say build or haddock targets).
    selectReplTargets =
      selectTargets
        verbosity
        ReplDefaultComponent
        ReplSpecificComponent

