<?php
$year = 2011;

require_once('../db.inc.php');
$db_name = "misc";

$db = mysql_connect($db_host, $db_user, $db_pass) or die("Connection Failed!");
mysql_select_db("misc", $db) or die("Could not select DB");

$sql = "SELECT id
  FROM card_exchange
  WHERE years = '$year'";
$result = mysql_query($sql);
$num_registrants = mysql_num_rows($result);

if ($_POST['submit'] == true)
{
  foreach ($_POST as $key => $val)
  {
    $_POST[$key] = trim($val);
  }

  extract($_POST);
  $real_name = isset($real_name) ? $real_name : $real_name_ecard;
  $errors = array();

  if (empty($codexed_user))
  {
    $errors[] = "Please enter your Codexed username.";
  }
  
  $email_regex = "%^
    (?:
      (?#local-part)
        (?#quoted)\"[^\\\"]*\"|
        (?#non-quoted)[a-z0-9&+_-](?:\.?[a-z0-9&+_-]+)*
    )
    @
    (?:
      (?#domain)
        (?#domain-name)[a-z0-9](?:[a-z0-9-]*[a-z0-9])*(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])*)*|
        (?#ip)(\[)?(?:[01]?\d?\d|2[0-4]\d|25[0-5])(?:\.(?:[01]?\d?\d|2[0-4]\d|25[0-5])){3}(?(1)\]|)
    )$%ix";
  if (!preg_match($email_regex, $email))
  {
    $errors[] = "Please enter a valid email address.";
  }
  
  if ($ecard_only == 0)
  {
    if (empty($real_name))
    {
      $errors[] = "Please enter your real name.";
    }
    if (empty($address))
    {
      $errors[] = "Please enter your full address.";
    }
  }

  if (!count($errors))
  {
    if (!empty($codexed_user))
    {
      $sql = "SELECT 1
        FROM card_exchange
        WHERE codexed_user = '$codexed_user'
          AND years = '$year'";
      $result = mysql_query($sql, $db);
      if (mysql_num_rows($result) > 0)
      {
        $errors[] = "The Codexed username you gave is already registered for $year.";
      }
    }

    if (!count($errors))
    {
      $sql = sprintf("INSERT INTO card_exchange
        (codexed_user,email, real_name, address, ecard_only, years)
        VALUES
        ('%s', '%s', '%s', '%s', %d, '$year')",
        mysql_real_escape_string($codexed_user),
        mysql_real_escape_string($email),
        mysql_real_escape_string($real_name),
        mysql_real_escape_string($address),
        mysql_real_escape_string($ecard_only));
      $result = mysql_query($sql, $db)
        or die("Insert into database failed! Contact administrator. Error message: " . mysql_error());
      echo "Thank you for signing up for the $year Card Exchange! Stay tuned to the forums for more information.";
      die();
    }
  }
}
?>

<html>
	<head>
		<title><?=$year?> CDX Card Exchange Registry</title>
		<script type="text/javascript">
			function getStyleClass (className)
			{
				for (var s = 0; s < document.styleSheets.length; s++)
				{
					if (document.styleSheets[s].rules)
					{
						for (var r = 0; r < document.styleSheets[s].rules.length; r++)
						{
							if (document.styleSheets[s].rules[r].selectorText == '.' + className)
							{
								return document.styleSheets[s].rules[r];
							}
						}
					}
					else if (document.styleSheets[s].cssRules)
					{
						for (var r = 0; r < document.styleSheets[s].cssRules.length; r++)
						{
							if (document.styleSheets[s].cssRules[r].selectorText == '.' + className)
								return document.styleSheets[s].cssRules[r];
						}
					}
				}
				
				return null;
			}

			function show_address(show)
			{
				var visible_state = document.getElementById('a_tr').style.display;

				if (show)
				{
					getStyleClass('address').style.display = visible_state;
					getStyleClass('ecard').style.display = 'none';
				}
				else
				{
					getStyleClass('address').style.display = 'none';
					getStyleClass('ecard').style.display = visible_state;
				}
			}

			function check_fields(frm)
			{
				if (frm.codexed_user.value.match(/^\s*$/))
				{
					alert("Please enter your Codexed username, or both.");
					frm.codexed_user.value = frm.dx_user.value = "";
					frm.codexed_user.focus();
					frm.codexed_user.select();
					return false;
				}

				<?php
					$email_regex = '/^(?:\"[^\\\"]*\"|[a-z0-9&+_-](?:\.?[a-z0-9&+_-]+)*)'
						. '@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])*(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])*)*|'
						. '(?:\[(?:[01]?\d?\d|2[0-4]\d|25[0-5])(?:\.(?:[01]?\d?\d|2[0-4]\d|25[0-5])){3}\]|'
						. '(?:[01]?\d?\d|2[0-4]\d|25[0-5])(?:\.(?:[01]?\d?\d|2[0-4]\d|25[0-5])){3}))$/i';
				?>
				
				if (!frm.email.value.match(<?=$email_regex?>))
				{
					alert("Please enter a valid email address.");
					frm.email.focus()
					frm.email.select();
					return false;
				}
				
				if (document.getElementById('ecard_0').checked == true)
				{
					if (frm.real_name.value.match(/^\s*$/))
					{
						alert("Please enter your real name.");
						frm.real_name.focus();
						frm.real_name.select();
						frm.real_name.value = "";
						return false;
					}

					if (frm.address.value.match(/^\s*$/))
					{
						alert("Please enter your full address.");
						frm.address.focus();
						frm.address.value = "";
						return false;
					}
				}
			}
		</script>
		<style>
			.address {}
			.ecard { display: none; }
			.spacer { empty-cells: show; padding-top: 10px; }
		</style>
	</head>
	<body>
		<h2><?=$year?> CDX Card Exchange Registry</h2>
    <p>
      The Codexed Card Exchange is an annual event (since Diary-X) in which members send holiday cards to each other.
      If you would like to participate, fill out the form below. We'd appreciate it if you only signed up if you
      intend on sending out cards yourself; while circumstances (be it time or cost) can make it difficult or
      impossible to send a card to everyone on the list (especially if there are a lot of people signed up),
      it is not fun for a participant to send everyone cards and receive none in return!
    </p>
    <h3>Deadlines</h3>
    <ul>
      <li><b>Registration:</b> 30 November 2011</li>
    </ul>
    <h3>Instructions</h3>
		<ul>
			<li>Fill out your information below to be signed up for the <?=$year?> Codexed holiday season Card Exchange.</li>
			<li>You can opt	to only receive e-cards if you do not want to give out your home address.</li>
			<li>Your Codexed username must be given.</li>
			<li>All information must be properly filled	out or else your registration will be invalid.</li>
			<li>There <?=$num_registrants != 1? 'are' : 'is'?> currently <b><?=$num_registrants?></b>
			user<?=$num_registrants != 1 ? 's' : ''?> signed up for the <?=$year?> Card Exchange.</li>
		</ul>
		<?php
		if (count($errors))
		{ ?>
		<div style="color: red;">
		Please fix the following errors:
		<ul style="margin-top: 0;">
			<?php
			foreach ($errors as $e_msg)
			{
				echo "<li>$e_msg</li>\n";
			}
			?>
		</ul>
		</div>
		<?php
		}
		?>
		<form method="post" onsubmit="return check_fields(this);">
		<table>
			<tr>
				<td>E-cards only?</td>
				<td>
					<input onclick="show_address(false);" type="radio" name="ecard_only" value="1" id="ecard_1"
						<?=$ecard_only == 1 ? 'checked="checked"' : ''?>
					/>
					<label for="ecard_1">Yes</label>
					<input onclick="show_address(true);" type="radio" name="ecard_only" value="0" id="ecard_0"
						<?=$ecard_only == 0 || !isset($ecard_only) ? 'checked="checked"' : ''?>
					/>
					<label for="ecard_0">No</label>
				</td>
			</tr>
			<tr>
				<td colspan="2" class="spacer"></td>
			</tr>
			<tr id="a_tr">
				<td style="padding-right: 5px;">Codexed username*:</td>
				<td><input type="text" name="codexed_user" value="<?=$codexed_user?>" /></td>
			</tr>
			<tr>
				<td>Email Address*:</td>
				<td style="padding-right: 20px;"><input type="text" name="email" size="50" value="<?=$email?>" /></td>
			</tr>
			<tr class="ecard">
				<td>Real Name:</td>
				<td><input type="text" name="real_name_ecard" value="<?=$real_name?>" /></td>
			</tr>
			<tr>
				<td colspan="2" class="spacer"></td>
			</tr>
			<tr class="address">
				<td>Real Name*:</td>
				<td><input type="text" name="real_name" value="<?=$real_name?>" /></td>
			</tr>
			<tr class="address">
				<td colspan="2">Address (exactly how it should appear on an envelope, <b>including country!</b>)*:</td>
			</tr>
			<tr class="address">
				<td colspan="2">
					<textarea rows="4" cols="50" name="address"><?=$address?></textarea>
				</td>
			</tr>
			<tr class="address">
				<td colspan="2" class="spacer"></td>
			</tr>
			<tr>
				<td colspan="2">
					<input type="hidden" name="submit" value="true" />
					<input type="submit" name="thesubmit" value="Sign up!" />
				</td>
			</tr>
			<tr>
				<td colspan="2" class="spacer"></td>
			</tr>
			<tr>
				<td colspan="2">
					* Denotes required field
				</td>
			</tr>
		</table>
		</form>
		<?php
    if ($ecard_only == 1)
    { ?>
      <script type="text/javascript">
        show_address(false);
      </script>
    <?php
    }
		?>
	</body>
</html>
