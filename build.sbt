TaskKey[Unit]("updateYml") := {
  import scala.sys.process.Process

  Process("yq", Seq("e", "-i", s""".inputs.sbt-runner-version.default = "${sbtVersion.value}"""", "action.yml")).!
}
