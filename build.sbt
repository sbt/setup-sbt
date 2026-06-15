import java.util.regex.Pattern

@transient
lazy val updateYml = taskKey[Unit]("")

updateYml := {

  val location = baseDirectory.value / "action.yml"
  val oldContent = IO.read(location)

  val matcher = Pattern.compile("default: (.+)$", Pattern.MULTILINE).matcher(oldContent)
  if (matcher.find) {
    val oldVersion = matcher.group(1)
    val updatedContent = oldContent.replace(s"default: $oldVersion", s"default: ${sbtVersion.value}")
    IO.write(location, updatedContent)
  }
}
