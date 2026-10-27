/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */
namespace HTL\Pha;

/** An attribute argument that could not be extracted as a pragma. */
final class PragmaExtractionDiagnostic {
  public function __construct(
    private Syntax $attribute,
    private Node $argument,
    private string $message,
  )[] {}

  public function getAttribute()[]: Syntax {
    return $this->attribute;
  }

  public function getArgument()[]: Node {
    return $this->argument;
  }

  public function getMessage()[]: string {
    return $this->message;
  }
}
