<?php
if (!isset($_POST['email']))
{
	require_once("invitation_form.php");
	die();
}

require_once('db.inc.php');
$db_name = "live";

$link = mysql_connect($db_host, $db_user, $db_pass);
$db_selected = mysql_select_db($db_name, $link);
	
$contact_email = "admin@codexed.com";
$contact_email_link = '<a href="mailto:' . $contact_email . '">' . $contact_email . '</a>';

if ($link === false || $db_selected === false)
{
	// Problem with the database
	$error = "There appears to be a problem connecting to the database.
		Please try again in a few minutes or send an email to
		$contact_email_link for more help.";
}
else
{
	$email = isset($_POST['email']) ? $_POST['email'] : NULL;
	$email_regex = '/^[\w.-]+@[\w-]+(\.[\w-]+)+/i';

	if (is_null($email) || empty($email))
	{
		$error = "No email address was provided.";
	}
	elseif (!preg_match($email_regex, $email))
	{
		$error = "The email address provided [$email] does not appear to be
			valid. Please enter a valid email address or email
			$contact_email_link for	more help.";
	}
	else
	{
		$query = "SELECT 1
			FROM invitation_codes
			WHERE email_address = '$email'";
		$result = mysql_query($query);
		if (mysql_num_rows($result) != 0)
		{
			$error = "The email address provided has already been sent an
				invitation code. Please email $contact_email_link if you
				are having trouble using it or have lost it.";
		}
	}
	
	if (!isset($error))
	{
		$md5 = md5($email . date("U"));

		// Add code to table
    mysql_query("BEGIN");
		$query = "INSERT INTO invitation_codes(name, email_address)
			VALUES ('$md5', '$email')";
		$result = mysql_query($query);
		if ($result === false)
		{
			$error = "There appears to have been a database error.
				Please try again in a few minutes or send an email to
				$contact_email_link for more help.";
		}
		else
		{
			// Send an email with the invitation code:
      $signup_link = "http://www.codexed.com/signup?code=$md5";
			$html_message = "<html>\n<body>\n"
				. "Please do not reply to this email.<br /><br />\n"
				. "Thank you for requesting an invitation code for "
				. "<a href=\"http://www.codexed.com\">Codexed.com</a>.<br /><br />\n"
				. "Your invitation code is: <b>$md5</b><br /><br />\n"
				. "The Codexed.com beta is now up and running, and you "
        . "can now use your invitation code by visiting "
        . "<a href=\"$signup_link\">$signup_link</a>.<br /><br />\n"
				. "The Codexed Team<br />\n"
				. "<a href=\"http://www.codexed.com\">http://www.codexed.com</a>\n"
				. "</body>\n</html>\n";

			$find = array('/\n/', '/<br(\s*\/)?>/');
			$repl = array('', "\n");
			$text_message = strip_tags(preg_replace($find, $repl, $html_message));

			$mime_boundary = "==Multipart_Boundary_x" . md5(time());
			$message = "This is a multipart MIME message.\n\n"
				. "--$mime_boundary\n"
				. "Content-Type: text/plain; charset=\"iso-8859-1\"\n"
				. "Content-Transfer-Encoding: 7bit\n\n"
				. $text_message . "\n\n"
				. "--$mime_boundary\n"
				. "Content-Type: text/html; charset=\"iso-8859-1\"\n"
				. "Content-Transfer-Encoding: 7bit\n\n"
				. $html_message . "\n\n"
				. "--$mime_boundary--";

			$subject = "Codexed.com invitation code";
			$from = "Codexed automailer <automailer@codexed.com>";
			$headers = array(
				"MIME-Version: 1.0",
				//"Content-Type: text/html; charset=\"iso-8859-1\"",
				"Content-Type: multipart/alternative; boundary=\"$mime_boundary\"",
				"From: $from",
				"X-Mailer: PHP/" . phpversion()
			);
			$ret = mail($email, $subject, $message, join("\r\n", $headers) . "\n\n");

			if ($ret === false)
			{
				$error = "Sending an email to the address provided failed.
					Please enter a valid email address or email
					$contact_email_link for	more help.";
          mysql_query("ROLLBACK");
			}
      else
      {
        mysql_query("COMMIT");
      }
		}
	}
}
 
if (isset($error))
{
	if ($link !== false) mysql_close($link);
	include("invitation_form.php");
}
else
{ ?>
	Thank you for your interest in Codexed and for requesting a code.<br />
	Your invitation code has been emailed to <?=$email?>.<br /><br />
	Return to the <a href="http://forums.codexed.com">Codexed forums</a>.
<?php
}
?>
