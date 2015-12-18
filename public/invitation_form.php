<html>
	<head>
		<title>Codexed.com invitations codes</title>
		<style type="text/css">
			div.error
			{
				font-weight: bold;
				border: 1px solid black;
				background: #FF6F6F;
				text-align: center;
			}
		</style>
	</head>
	<body>
		<?php
		if (isset($error))
		{
			echo '<div class="error">' . $error . '</div>' . "\n";
		}
		?>
		
		<h2>Request an invitation code</h2>
		<p>The Codexed beta test is now open! However, you will not be able to
    register an account without a valid, and unused, invitation code.</p>
		<p>Fill out the following form in order to receive an invitation code
		for the Codexed beta test. It may take up to 24 hours for you to receive
		your code. If you have not received your code after 24 hours, please
		send an email to <a href="mailto:admin@codexed.com">admin@codexed.com</a>
		and we will help you out.</p>
    <p>Please note that Codexed registrations are limited to <b>one account
    per person</b> for the time being!</p>

		<form method="post" action="invitation.php">
			<table>
				<tr>
					<td style="font-weight: bold;">Email address:</td>
					<td>
						<input type="text" name="email" size="20" value="<?=$email?>" />
					</td>
				</tr>
				<tr>
					<td colspan="2">
						<input type="submit" value="Request your invitation code!" />
					</td>
				</tr>
			</table>
		</form>
	</body>
</html>
