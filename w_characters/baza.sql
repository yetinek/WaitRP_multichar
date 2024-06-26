SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


ALTER TABLE `users`
  ADD COLUMN `hiddenjob` varchar(244) DEFAULT 'Brak',
  ADD COLUMN `ssn` varchar(244) DEFAULT 'brak' AFTER `hiddenjob`,
  ADD COLUMN `nationality` varchar(124) NOT NULL AFTER `ssn`,
  ADD COLUMN `playtime` int(11) DEFAULT 0 AFTER `nationality`;

CREATE TABLE `user_lastcharacter` (
  `license` varchar(255) NOT NULL,
  `charid` int(11) NOT NULL DEFAULT 1,
  `limit` int(11) NOT NULL DEFAULT 1,
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;


ALTER TABLE `user_lastcharacter`
  ADD PRIMARY KEY (`license`);
COMMIT;
